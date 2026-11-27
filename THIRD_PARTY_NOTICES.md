# Third-party notices

This repository contains original MusikKu iOS integration code and components derived from or linked against the upstream projects below. Preserve the copyright notices and licenses for each component when redistributing the application.

## Upstream application project — BitChord

- Project: https://github.com/kushagrasinghx/BitChord
- License: GNU General Public License v3.0 (GPL-3.0)
- The native port adapts the upstream application structure and functionality. The upstream project's copyright notices, license text, and source attribution must remain intact where required.

## InnerTubeX resolver

- Project: https://github.com/MetrolistGroup/innertubex
- Version used by the iOS resolver target: `v0.13.2`
- License: GNU General Public License v3.0 (GPL-3.0)
- The project metadata identifies GPL-3.0. The iOS Kotlin Multiplatform target links this resolver into `MusikKuResolverKit.xcframework`.

## QuackJS JavaScript runtime

- Project: https://github.com/MetrolistGroup/quackjs
- Version pulled transitively by InnerTubeX v0.13.2: `0.1.4`
- License: GNU General Public License v3.0 (GPL-3.0)
- InnerTubeX uses QuackJS for bounded YouTube player JavaScript processing.

## Ktor networking

- Project: https://github.com/ktorio/ktor
- Version used by the iOS target: `3.6.0` (Darwin engine)
- License: Apache License 2.0 (Apache-2.0)
- Ktor source and license: https://github.com/ktorio/ktor/blob/main/LICENSE

## Redistribution and corresponding source

The repository includes the GPL-3.0 license text in [LICENSE](LICENSE). When conveying a binary or modified version, review the applicable GPL-3.0 requirements for notices, license text, corresponding source, modification notices, and (where applicable) installation information for a User Product. Confirm that the planned App Store/TestFlight or sideload distribution method can satisfy the obligations before distributing binaries.

Do not treat this notice as legal advice or as a complete software bill of materials. Re-check the resolved Gradle dependency graph and licenses for the exact release build, including any updated or newly added transitive dependencies. Include any required Apache-2.0 notices and dependency license texts with the release materials.
