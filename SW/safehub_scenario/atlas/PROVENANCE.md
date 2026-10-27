# Scenario runner candidate

This runner is copied from `SW/safehub_app/atlas` at PR #8
`9037ac901b0ef16a67a4b7a9d519a7d46d18de1e`. The CMake app ID,
manifest ID/entry, display name and manifest version are adapted for the
user-confirmed Scenario app. The Dart package and executable remain `safehub_app`;
the installed app ID remains `com.atlas.app.safehub_scenario_pr7`.

The submission source candidate is `1.6.0` (pubspec `1.6.0+1`), not an
installed-device claim. The earlier user observation was 1.2.0; PR #10 reported
1.4.0 and PR #14's later device notes report 1.5.7. The cloud integration has not
read the current installed manifest or verified the final ELF/kernel against
this source tree. Obtain the installed manifest, source/build archive, tool
versions and IPK/ELF hashes before declaring that correspondence.
The media-player permission and plugin registration are retained from the
existing runner; no new permission is invented. Validate them with the installed
package, the ATLAS SDK and hardware before deployment.

`atlas/README.md` describes the inherited runner/SDK mechanics. Run all build
commands from `SW/safehub_scenario`, with the target ATLAS SDK and its
`audioplayers_atlas` path dependency available. Host Flutter tests use
`python3 tool/prepare_host_tests.py /tmp/safehub-scenario-host` instead; that
disposable project excludes the two ATLAS plugins and cannot validate ATLAS ABI.

The copied runner is self-contained in this Scenario directory; its CMake and
plugin registration do not read the legacy safehub_app directory at build time.
The original path above records provenance, not a build dependency.
