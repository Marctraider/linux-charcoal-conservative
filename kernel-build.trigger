Trigger the full GitHub Actions kernel package build.
Retry full package build after fixing local makepkg source paths and incrementing kernel package release.

Retry kernel build with lore.landau.one mirror fallback for the AMD EPP RFC patch series.

Retry with explicit HTTP user agent for lore mirror access.

Retry after correcting the EPP importer checksum and adding persistent source-download and ccache caches.

Retry kernel build using locally vendored, Message-ID-verified AMD EPP RFC patches; no network dependency during prepare().

Retry after detecting RFC patch 1 is already present in Valve source.
