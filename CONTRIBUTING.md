# Contributing

Open an issue before adding a public API, runtime dependency, framework integration, or protocol field.

For each change:

1. keep syntax compatible with Ruby 2.2.10 on the 0.x line;
2. write or update unit, contract, and integration tests;
3. keep Core independent of frameworks and HTTP;
4. bound every queue, buffer, collection, timeout, and retry;
5. document public classes with responsibility, motivation, limits, collaborators, thread safety, compatibility, examples, errors, and performance where relevant;
6. update module documentation, ADRs, README, and changelog;
7. do not declare compatibility before its dedicated CI gate succeeds.

Run:

```bash
bin/setup
bundle _1.17.3_ exec rake
ruby script/verify_docs
```

Do not include credentials, personal data, production payloads, or proprietary third-party code in issues, fixtures, or pull requests.
