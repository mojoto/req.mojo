# Compatibility scenarios

The pinned baseline is version 0.28.1, revision
`26d48e0634e6ee9cdc0533996db289ce4b430177`.

The baseline contains **539 test functions and 1,418 collected cases** after
parameter expansion. The native suite contains **296 test functions**, including
parameter tables. Function counts and expanded case counts are different units.

| Inventory | Mapped to native tests | Excluded | Total |
| --- | ---: | ---: | ---: |
| Baseline functions (`baseline.json`) | 226 | 313 | 539 |
| Expanded cases (`case_inventory.json`) | 493 | 925 | 1,418 |

Each expanded case has an individual disposition. Parameter-specific exclusions
include unsupported JSON charsets, Brotli and dynamic dictionary coercion; these
are not counted as mapped just because another parameter of the same function
has a native equivalent. The `scope` entries identify omitted assertions and
native contract differences. A mapping means the supported or adapted behavior
is exercised; it does **not** claim identical APIs or all baseline assertions.
Some async/backend repetitions map to the same synchronous native test.

`make test` validates all identities, function references, native test targets
and executable URL table keys before compiling and running the suite. This is
an inventory consistency check, not an assertion-equivalence proof. No baseline
download or extra Python dependency is required.

`url_cases.mojo` executes all 229 applicable HTTP(S) canonical URL rows, without
deduplicating repeated addresses: 194 parse cases and 35 native-policy rejection
cases. The remaining 334 canonical corpus rows use schemes outside the API.
The corpus parses canonical `href`, matching the baseline scenario, rather than
implementing browser parsing of the original input and base values. Native
checks retain scheme, host, effective port, encoded path and query assertions;
fragments are deliberately discarded.

Additional matrices exercise 65 method/status/body redirect combinations and
108 encoding/payload/read-size combinations over fragmented chunked HTTP.
Payloads include empty bodies, text and every byte value. Both wrapped and raw
deflate are tested alone and below gzip. URL control characters are checked in
path, query and fragment positions. These local regressions strengthen coverage
without treating them as additional collected baseline cases.

The native scenarios also cover synchronous request methods, forms, UTF-8 JSON,
headers and query parameters, RFC 3986 resolution, cookies, Basic authentication,
redirects, TLS verification, phase timeouts and decoded byte streaming.

The current API has these deliberate boundaries:

- URL values are absolute HTTP(S) addresses with ASCII or IPv6 hosts. They reject
  userinfo, malformed path/query escapes, control characters, invalid IP literals
  and inputs over 65,536 bytes. Fragments are discarded, paths remain encoded,
  and absolute paths retain dot segments. Relative references use RFC 3986.
- Query parameters use String pairs and encode URL spaces as `%20`; form bodies
  use `+`. Header lookup returns the first value, with `get_all()` preserving
  duplicates. Collection mutation and length follow the native pair model.
- Responses require a Request. Status errors cover 4xx/5xx. Text decoding supports
  UTF-8, ASCII and Latin-1 with strict errors and per-call encoding overrides.
  JSON bytes support UTF-8 with or without a BOM. Response chunk reads return decoded bytes.
- Client configuration is supplied by constructor and per-request arguments.
  Automatic transport headers are checked on the wire. Credentials are removed
  whenever the origin changes; HTTPS-to-HTTP redirects are rejected.

Excluded scenarios require APIs outside the current scope: async clients,
streaming uploads, custom or application transports, multipart, proxies, Digest
authentication, event hooks, Python-specific representations and serialization,
IDNA conversion, extra compression/charset codecs, text/line/raw iterators or
configuration interfaces absent from the native API. Their individual reasons
are recorded so future capability additions can revisit them. Missing test
fixtures are not exclusion reasons: origin changes use the real local transport.

The license for adapted baseline scenario data is preserved in `LICENSE.md`.
