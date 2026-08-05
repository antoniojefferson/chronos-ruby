module Chronos
  module Core
    # Derives bounded query-shape evidence and index recommendations from normalized SQL.
    #
    # @responsibility Extract tables and access columns, compare index metadata, and emit diagnostics.
    # @motivation Give the Chronos consumer actionable SQL evidence without collecting binds or raw SQL.
    # @limits It is a defensive heuristic for SELECT statements, not a dialect-complete parser or optimizer.
    # @collaborators SqlNormalizer and an optional query-inspection adapter.
    # @thread_safety Instances are stateless and safe to share.
    # @compatibility Ruby 2.2.10 through Ruby 2.6; independent of Rails and database drivers.
    # @example
    #   SqlQueryAnalyzer.new.call("normalized_query" => "SELECT * FROM users WHERE email = ?")
    # @errors Malformed input returns an empty bounded analysis and never escapes.
    # @performance Input, tables, columns, candidates, diagnostics, and inspection evidence are capped.
    class SqlQueryAnalyzer # rubocop:disable Metrics/ClassLength
      MAX_TABLES = 8
      MAX_COLUMNS = 12
      MAX_INDEXES = 20
      MAX_DIAGNOSTICS = 20
      IDENTIFIER = "[A-Za-z_][A-Za-z0-9_$]*".freeze
      TABLE_PATTERN = /\b(?:FROM|JOIN)\s+["`\[]?(#{IDENTIFIER}(?:\.#{IDENTIFIER})?)["`\]]?
                       (?:\s+(?:AS\s+)?(#{IDENTIFIER}))?/ix
      CLAUSE_END = /\b(?:GROUP\s+BY|ORDER\s+BY|HAVING|LIMIT|OFFSET|UNION|RETURNING)\b/i
      RESERVED = %w(WHERE JOIN LEFT RIGHT INNER OUTER FULL CROSS ON GROUP ORDER HAVING LIMIT OFFSET).freeze

      def call(query, inspection = {})
        data = hash(query)
        normalized = bounded(data["normalized_query"] || data[:normalized_query], 512)
        operation = (data["operation"] || data[:operation]).to_s.upcase
        return empty_analysis(operation) unless operation == "SELECT" && !normalized.empty?

        aliases = table_aliases(normalized, data["table"] || data[:table])
        access = access_columns(normalized, aliases)
        candidates = index_candidates(access, hash(inspection))
        evidence = inspection_evidence(inspection)
        {
          "operation" => operation,
          "tables" => aliases.values.uniq.first(MAX_TABLES),
          "access_columns" => access,
          "index_candidates" => candidates,
          "inspection" => evidence,
          "diagnostics" => diagnostics(candidates, evidence)
        }
      rescue StandardError
        empty_analysis("UNKNOWN")
      end

      private

      def empty_analysis(operation)
        {
          "operation" => operation.to_s.empty? ? "UNKNOWN" : operation.to_s,
          "tables" => [], "access_columns" => {}, "index_candidates" => [],
          "inspection" => {}, "diagnostics" => []
        }
      end

      def table_aliases(sql, fallback)
        result = {}
        sql.scan(TABLE_PATTERN) do |table, name|
          alias_name = name.to_s
          alias_name = table.to_s.split(".").last if alias_name.empty? || RESERVED.include?(alias_name.upcase)
          result[alias_name] = bounded_identifier(table)
          break if result.length >= MAX_TABLES
        end
        if result.empty? && !fallback.to_s.empty?
          table = bounded_identifier(fallback)
          result[table.split(".").last] = table unless table.empty?
        end
        result
      end

      def access_columns(sql, aliases)
        result = {}
        aliases.values.uniq.each do |table|
          result[table] = {"equality" => [], "range" => [], "join" => [], "order" => []}
        end
        base_table = aliases.values.first
        where = clause(sql, /\bWHERE\b/i, CLAUSE_END)
        collect_predicates(where, aliases, base_table, result)
        collect_join_predicates(sql, aliases, result)
        collect_order_columns(clause(sql, /\bORDER\s+BY\b/i, /\b(?:LIMIT|OFFSET|UNION|RETURNING)\b/i), aliases,
                              base_table, result)
        result.delete_if { |_table, groups| groups.values.all?(&:empty?) }
      end

      def collect_predicates(section, aliases, base_table, result)
        return if section.empty?

        pattern = /(?:(#{IDENTIFIER})\.)?(#{IDENTIFIER})\s*(=|<>|!=|<=|>=|<|>|\bIN\b|\bIS\b|\bLIKE\b)/i
        section.scan(pattern).each do |alias_name, column, operator|
          table = alias_name.to_s.empty? ? base_table : aliases[alias_name]
          next unless table && result[table]

          group = ["=", "IN", "IS"].include?(operator.to_s.upcase) ? "equality" : "range"
          append_column(result[table][group], column)
        end
      end

      def collect_join_predicates(sql, aliases, result)
        sql.scan(/\bON\b(.*?)(?=\b(?:JOIN|WHERE|GROUP\s+BY|ORDER\s+BY|HAVING|LIMIT|OFFSET)\b|\z)/im) do |match|
          match.first.to_s.scan(/(#{IDENTIFIER})\.(#{IDENTIFIER})/i).each do |alias_name, column|
            table = aliases[alias_name]
            append_column(result[table]["join"], column) if table && result[table]
          end
        end
      end

      def collect_order_columns(section, aliases, base_table, result)
        section.split(",").first(MAX_COLUMNS).each do |item|
          match = item.match(/(?:(#{IDENTIFIER})\.)?(#{IDENTIFIER})(?:\s+(?:ASC|DESC))?/i)
          next unless match

          table = match[1].to_s.empty? ? base_table : aliases[match[1]]
          append_column(result[table]["order"], match[2]) if table && result[table]
        end
      end

      def index_candidates(access, inspection)
        indexes = Array(inspection["indexes"] || inspection[:indexes]).first(MAX_INDEXES)
        access.map do |table, groups|
          columns = (groups["equality"] + groups["join"] + groups["range"] + groups["order"]).uniq.first(MAX_COLUMNS)
          next if columns.empty?

          covering = indexes.find { |index| index_covers?(index, table, columns) }
          {
            "table" => table, "columns" => columns,
            "status" => candidate_status(indexes, covering),
            "covered_by" => covering ? bounded(hash(covering)["name"] || hash(covering)[:name], 128) : nil,
            "confidence" => candidate_confidence(inspection, covering)
          }.delete_if { |_key, value| value.nil? || value == "" }
        end.compact.first(MAX_TABLES)
      end

      def candidate_status(indexes, covering)
        return "unverified" if indexes.empty?

        covering ? "covered" : "missing"
      end

      def index_covers?(index, table, columns)
        data = hash(index)
        return false unless (data["table"] || data[:table]).to_s == table.to_s

        existing = Array(data["columns"] || data[:columns]).map(&:to_s)
        existing.first(columns.length) == columns
      end

      def candidate_confidence(inspection, covering)
        return "high" if covering

        plan = hash(hash(inspection)["plan"] || hash(inspection)[:plan])
        return "high" if plan["sequential_scan"] == true || plan[:sequential_scan] == true
        return "medium" unless Array(hash(inspection)["indexes"] || hash(inspection)[:indexes]).empty?

        "low"
      end

      def inspection_evidence(value)
        data = hash(value)
        result = {"indexes" => bounded_indexes(data["indexes"] || data[:indexes])}
        statistics = hash(data["statistics"] || data[:statistics])
        result["statistics"] = bounded_statistics(statistics) unless statistics.empty?
        plan = hash(data["plan"] || data[:plan])
        result["plan"] = bounded_plan(plan) unless plan.empty?
        errors = bounded_errors(data["errors"] || data[:errors])
        result["errors"] = errors unless errors.empty?
        result
      end

      def bounded_indexes(values)
        Array(values).first(MAX_INDEXES).map do |index|
          item = hash(index)
          columns = Array(item["columns"] || item[:columns]).first(MAX_COLUMNS)
          {
            "table" => bounded_identifier(item["table"] || item[:table]),
            "name" => bounded(item["name"] || item[:name], 128),
            "columns" => columns.map { |column| bounded_identifier(column) },
            "unique" => item["unique"] == true || item[:unique] == true
          }
        end
      end

      def bounded_errors(values)
        Array(values).first(5).map { |error| bounded(error, 128) }
      end

      def bounded_statistics(statistics)
        {
          "estimated_rows" => non_negative_integer(statistics["estimated_rows"] || statistics[:estimated_rows]),
          "source" => bounded(statistics["source"] || statistics[:source], 64)
        }.delete_if { |_key, value| value.nil? || value == "" }
      end

      def bounded_plan(plan)
        {
          "nodes" => Array(plan["nodes"] || plan[:nodes]).first(20).map do |node|
            bounded_plan_node(node)
          end,
          "uses_index" => plan["uses_index"] == true || plan[:uses_index] == true,
          "sequential_scan" => plan["sequential_scan"] == true || plan[:sequential_scan] == true
        }
      end

      def bounded_plan_node(node)
        data = hash(node)
        {
          "type" => bounded(data["type"] || data[:type], 64),
          "table" => bounded_identifier(data["table"] || data[:table]),
          "index" => bounded(data["index"] || data[:index], 128),
          "estimated_rows" => non_negative_integer(data["estimated_rows"] || data[:estimated_rows]),
          "total_cost" => non_negative_number(data["total_cost"] || data[:total_cost])
        }.delete_if { |_key, child| child.nil? || child == "" }
      end

      def diagnostics(candidates, inspection)
        result = [diagnostic("query_pattern_analyzed", "info", "query_pattern", {},
                             "Normalized SELECT access pattern was analyzed")]
        candidates.each do |candidate|
          status = candidate["status"]
          code = index_diagnostic_code(status)
          severity = status == "covered" ? "info" : "suggestion"
          result << diagnostic(code, severity, "index", candidate, index_diagnostic_message(status))
        end
        plan = hash(inspection["plan"])
        if plan["sequential_scan"] == true
          result << diagnostic("sequential_scan", "warning", "plan", {},
                               "The bounded query plan contains a sequential scan")
        end
        Array(inspection["errors"]).each do |error|
          result << diagnostic("query_inspection_failed", "error", "inspection", {"error_class" => error},
                               "Read-only query inspection failed")
        end
        result.first(MAX_DIAGNOSTICS)
      end

      def index_diagnostic_code(status)
        return "missing_index_candidate" if status == "missing"
        return "index_covered" if status == "covered"

        "index_candidate"
      end

      def index_diagnostic_message(status)
        return "Existing index covers the observed access pattern" if status == "covered"

        "Review a candidate index for the observed access pattern"
      end

      def diagnostic(code, severity, category, evidence, message)
        result = {
          "code" => code, "severity" => severity, "category" => category,
          "message" => message, "evidence" => evidence
        }
        if severity == "suggestion"
          result["recommendation"] = "Validate selectivity and write cost before creating the candidate index"
        end
        result
      end

      def clause(sql, start_pattern, finish_pattern)
        start = sql.index(start_pattern)
        return "" unless start

        tail = sql[start..-1].to_s.sub(start_pattern, "")
        finish = tail.index(finish_pattern)
        finish ? tail[0...finish] : tail
      end

      def append_column(collection, value)
        column = bounded_identifier(value)
        collection << column if !column.empty? && !collection.include?(column) && collection.length < MAX_COLUMNS
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

      def non_negative_integer(value)
        return nil if value.nil?

        [value.to_i, 0].max
      rescue StandardError
        nil
      end

      def non_negative_number(value)
        return nil if value.nil?

        number = value.to_f
        number < 0.0 ? 0.0 : number
      rescue StandardError
        nil
      end

      def hash(value)
        value.is_a?(Hash) ? value : {}
      end
    end
  end
end
