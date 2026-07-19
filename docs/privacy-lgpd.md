# Privacy and LGPD

Version 0.1 enforces structural limits but does not yet implement the recursive sensitive-data sanitizer planned for version 0.2.

Applications must not pass passwords, tokens, authorization headers, cookies, session secrets, private keys, card data, CPF, CNPJ, health data, or other unnecessary personal information.

Recommended practice:

1. pass opaque internal identifiers instead of names or e-mail addresses;
2. allowlist context fields in application code;
3. inspect payloads against a local fake server before production;
4. keep TLS verification enabled;
5. document the lawful purpose and retention policy in the SaaS;
6. disable the agent in environments where collection is not authorized.

Version 0.1 limits object depth, hash keys, array items, string bytes, backtrace frames, queue capacity, and total payload size. Unknown Ruby objects are represented by class name without calling their `to_json` implementation.
