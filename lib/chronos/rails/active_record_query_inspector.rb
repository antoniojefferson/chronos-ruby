require "json"

module Chronos
  module Rails
    # Performs bounded, read-only ActiveRecord index, statistics, and query-plan inspection.
    #
    # @responsibility Read public schema metadata and optional non-executing SELECT plans.
    # @motivation Add database evidence to query diagnostics without exposing raw SQL or bind values.
    # @limits It never runs EXPLAIN ANALYZE or DDL; support is best-effort and explicitly opt-in.
    # @collaborators An ActiveRecord connection supplied by sql.active_record notifications.
    # @thread_safety Calls use the notification connection and a thread-local recursion guard.
    # @compatibility Feature-detected Rails 4.2/5.2 connections for PostgreSQL and MySQL-family adapters.
    # @example
    #   inspector.call(sql, query_metadata, :plan => false)
    # @errors Adapter failures become bounded error-class evidence and never escape.
    # @performance Each uncached inspection adds schema/statistics queries and optionally EXPLAIN.
    class ActiveRecordQueryInspector
      GUARD_KEY = :__chronos_query_inspection
      MAX_PLAN_NODES = 20

      def self.suppressed?
        Thread.current[GUARD_KEY] == true
      rescue StandardError
        false
      end

      def call(raw_sql, query, options = {})
        connection = options[:connection]
        return {} unless eligible?(raw_sql, query, connection)

        previous = Thread.current[GUARD_KEY]
        Thread.current[GUARD_KEY] = true
        guarded = true
        result = {"errors" => []}
        capture(result) { result["indexes"] = indexes(connection, table(query)) }
        if options[:statistics] == true
          capture(result) { result["statistics"] = statistics(connection, table(query)) }
        end
        if options[:plan] == true
          capture(result) do
            plan_result = plan(connection, raw_sql, adapter_name(connection))
            result["errors"].concat(Array(plan_result.delete("errors")))
            result["plan"] = plan_result
          end
        end
        result.delete("errors") if result["errors"].empty?
        result
      rescue StandardError => error
        {"errors" => [safe_error_class(error)]}
      ensure
        Thread.current[GUARD_KEY] = previous if guarded
      end

      private

      def capture(result)
        yield
      rescue StandardError => error
        result["errors"] << safe_error_class(error) if result["errors"].length < 5
      end

      def eligible?(raw_sql, query, connection)
        return false unless connection
        return false unless (query["operation"] || query[:operation]).to_s == "SELECT"
        return false if table(query).empty?
        return false unless raw_sql.to_s.lstrip =~ /\ASELECT\b/i

        normalized = (query["normalized_query"] || query[:normalized_query]).to_s
        normalized.sub(/;\s*\z/, "") !~ /;/
      end

      def indexes(connection, table_name)
        return [] unless connection.respond_to?(:indexes)

        Array(connection.indexes(table_name)).first(20).map do |index|
          {
            "table" => bounded_identifier(table_name), "name" => bounded(value(index, :name), 128),
            "columns" => Array(value(index, :columns)).first(12).map { |column| bounded_identifier(column) },
            "unique" => value(index, :unique) == true
          }
        end
      end

      def statistics(connection, table_name)
        adapter = adapter_name(connection)
        if adapter =~ /postgres/i
          row = first_row(connection, "SELECT reltuples AS estimated_rows FROM pg_class WHERE oid = " \
                                      "#{quote(connection, table_name)}::regclass")
          return {"estimated_rows" => numeric(row, "estimated_rows"), "source" => "pg_class"}
        end
        if adapter =~ /mysql|trilogy/i
          sql = "SELECT table_rows AS estimated_rows FROM information_schema.tables " \
                "WHERE table_schema = DATABASE() AND table_name = #{quote(connection, table_name)}"
          row = first_row(connection, sql)
          return {"estimated_rows" => numeric(row, "estimated_rows"), "source" => "information_schema"}
        end

        {}
      end

      def plan(connection, raw_sql, adapter)
        return {} unless connection.respond_to?(:select_all)

        if adapter =~ /postgres/i
          rows = rows(connection.select_all("EXPLAIN (FORMAT JSON) #{raw_sql}"))
          return postgres_plan(rows)
        end
        if adapter =~ /mysql|trilogy/i
          return mysql_plan(rows(connection.select_all("EXPLAIN #{raw_sql}")))
        end

        {}
      end

      def postgres_plan(rows_value)
        raw = rows_value.first || {}
        document = raw["QUERY PLAN"] || raw["query_plan"] || raw.values.first
        parsed = document.is_a?(String) ? JSON.parse(document) : document
        root = Array(parsed).first
        root = root["Plan"] if root.is_a?(Hash) && root["Plan"]
        nodes = []
        collect_postgres_nodes(root, nodes)
        summarize_plan(nodes)
      rescue StandardError => error
        {"nodes" => [], "uses_index" => false, "sequential_scan" => false,
         "errors" => [safe_error_class(error)]}
      end

      def collect_postgres_nodes(node, result)
        return unless node.is_a?(Hash) && result.length < MAX_PLAN_NODES

        result << {
          "type" => bounded(node["Node Type"], 64),
          "table" => bounded_identifier(node["Relation Name"]),
          "index" => bounded(node["Index Name"], 128),
          "estimated_rows" => integer(node["Plan Rows"]),
          "total_cost" => number(node["Total Cost"])
        }.delete_if { |_key, child| child.nil? || child == "" }
        Array(node["Plans"]).each { |child| collect_postgres_nodes(child, result) }
      end

      def mysql_plan(rows_value)
        nodes = rows_value.first(MAX_PLAN_NODES).map do |row|
          {
            "type" => bounded(row["type"] || row[:type] || row["select_type"], 64),
            "table" => bounded_identifier(row["table"] || row[:table]),
            "index" => bounded(row["key"] || row[:key], 128),
            "estimated_rows" => integer(row["rows"] || row[:rows])
          }.delete_if { |_key, child| child.nil? || child == "" }
        end
        summarize_plan(nodes)
      end

      def summarize_plan(nodes)
        types = nodes.map { |node| node["type"].to_s }
        {
          "nodes" => nodes,
          "uses_index" => nodes.any? { |node| !node["index"].to_s.empty? || node["type"].to_s =~ /Index/i },
          "sequential_scan" => types.any? { |type| type =~ /Seq Scan|ALL/i }
        }
      end

      def first_row(connection, sql)
        return {} unless connection.respond_to?(:select_all)

        rows(connection.select_all(sql)).first || {}
      end

      def rows(value)
        return value.to_a if value.respond_to?(:to_a)

        Array(value)
      rescue StandardError
        []
      end

      def quote(connection, value)
        return connection.quote(value.to_s) if connection.respond_to?(:quote)

        "'#{value.to_s.gsub("'", "''")}'"
      end

      def adapter_name(connection)
        connection.respond_to?(:adapter_name) ? connection.adapter_name.to_s : ""
      rescue StandardError
        ""
      end

      def table(query)
        bounded_identifier(query["table"] || query[:table])
      end

      def value(object, method_name)
        object.respond_to?(method_name) ? object.public_send(method_name) : nil
      rescue StandardError
        nil
      end

      def numeric(row, key)
        value = row[key] || row[key.to_sym]
        integer(value)
      end

      def integer(value)
        value.nil? ? nil : [value.to_i, 0].max
      rescue StandardError
        nil
      end

      def number(value)
        value.nil? ? nil : [value.to_f, 0.0].max
      rescue StandardError
        nil
      end

      def safe_error_class(error)
        bounded(error.class.name.to_s, 128)
      rescue StandardError
        "StandardError"
      end

      def bounded_identifier(value)
        bounded(value, 128).gsub(/[^A-Za-z0-9_.$-]/, "")
      end

      def bounded(value, limit)
        text = value.to_s
        text = text.scrub("?") if text.respond_to?(:scrub)
        text.bytesize > limit ? text.byteslice(0, limit).to_s : text
      rescue StandardError
        ""
      end
    end
  end
end
