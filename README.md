# jwmv — Java Version Manager for Windows

A fast, lightweight CLI tool to install, manage, and switch between Java/JDK and JVM toolchain versions on Windows. Built with .NET 8, inspired by tools like [SDKMAN!](https://sdkman.io/) and [nvm](https://github.com/nvm-sh/nvm).

[![CI](https://github.com/stescobedo92/jwmv/actions/workflows/ci.yml/badge.svg)](https://github.com/stescobedo92/jwmv/actions/workflows/ci.yml)

---

## Features

- **Install JDKs and JVM SDKs** — Java via [Foojay Disco API](https://api.foojay.io/), plus Gradle, Maven, and Kotlin from official release feeds
- **Switch versions instantly** — per-session, per-project (`.jwmvrc`), or set persistent defaults per candidate
- **SDKMAN-style candidates** — list and install supported candidates with `jwmv candidates`, `jwmv list gradle`, and `jwmv install maven 3.9.15`
- **Verified downloads** — validates supported SHA-256/SHA-512 checksums before extraction
- **Shell integration** — PowerShell profile bootstrap for automatic version switching
- **Self-update** — update jwmv itself from GitHub Releases
- **Diagnostics** — `doctor` command detects PATH conflicts and misconfigurations
- **Single-file executable** — no runtime dependencies, just download and run
- **Windows x64 & ARM64** support

---

## Installation

### winget (recommended)

```powershell
winget install stescobedo92.jwmv
```

### npm

```bash
npm install -g @stescobedo9205/jwmv
```

> Downloads the native binary for your architecture automatically. No .NET runtime needed.

### .NET global tool

```bash
dotnet tool install -g jwmv
```

> Requires the .NET 8 runtime.

### Download from GitHub Releases

```powershell
# Download the latest release for your architecture
# https://github.com/stescobedo92/jwmv/releases

# Extract and place jwmv.exe somewhere in your PATH, for example:
Expand-Archive jwmv-win-x64.zip -DestinationPath "$HOME\.jwmv\bin"

# Add to PATH (run once)
[Environment]::SetEnvironmentVariable(
    "Path",
    "$HOME\.jwmv\bin;" + [Environment]::GetEnvironmentVariable("Path", "User"),
    "User"
)
```
---

## Quick Start

```powershell
# See what's available
jwmv candidates
jwmv list

# Install Java 21 (Temurin) and set it as default
jwmv install 21-tem --default

# Verify
jwmv current
java -version

# Install another version
jwmv install 17-zulu

# Install build tooling
jwmv install gradle 9.5.1
jwmv install maven 3.9.15
jwmv install kotlin 2.3.21

# Switch for this session
jwmv use 17-zulu
jwmv use gradle 9.5.1
```

---

## Commands

### `jwmv candidates [filter]`

List supported SDK installation candidates.

```powershell
jwmv candidates
jwmv candidates java
```

| Candidate | Source |
|-----------|--------|
| `java`   | Foojay Disco API |
| `gradle` | Gradle services version feed |
| `maven`  | Maven Central metadata |
| `kotlin` | JetBrains Kotlin GitHub Releases |

---

### `jwmv list [candidate] [filter]`

List available SDK versions. If the first argument is not a known candidate, it is treated as a legacy Java filter.

```powershell
# List Java versions
jwmv list java

# Legacy Java shorthand
jwmv list 21

# List Gradle versions
jwmv list gradle

# Filter by version
jwmv list maven 3.9

# Force catalog refresh
jwmv list kotlin --refresh
```

**Aliases:** `ls`

| Option          | Description                        |
|-----------------|------------------------------------|
| `[candidate]`   | Optional candidate name (`java`, `gradle`, `maven`, `kotlin`) |
| `[filter]`      | Optional version/distribution filter |
| `-r, --refresh` | Force refresh the catalog cache    |

---

### `jwmv install [candidate] [version]`

Install an SDK version. Java keeps the previous shorthand syntax for compatibility.

```powershell
# Interactive mode — prompts for filter and selection
jwmv install

# Java legacy shorthand
jwmv install 21-tem

# Explicit candidate syntax
jwmv install java 21-tem
jwmv install gradle 9.5.1
jwmv install maven 3.9.15
jwmv install kotlin 2.3.21

# Install and set as the default JAVA_HOME
jwmv install 21.0.4-tem --default

# Install with forced catalog refresh
jwmv install 17-zulu --refresh
```

| Option          | Description                                |
|-----------------|--------------------------------------------|
| `[candidate]`   | Candidate name, optional for Java shorthand |
| `[version]`     | Candidate version or Java identifier |
| `-d, --default` | Set as default SDK after install     |
| `-r, --refresh` | Force refresh the catalog before install   |

**Identifier format:** `<version>-<distribution>` where distribution is a short alias:

| Alias     | Distribution        |
|-----------|---------------------|
| `tem`     | Eclipse Temurin     |
| `zulu`    | Azul Zulu           |
| `ms`      | Microsoft OpenJDK   |
| `graalvm` | GraalVM Community   |
| `cor`     | Amazon Corretto     |
| `lib`     | Liberica            |
| `sap`     | SAP Machine         |
| `ojdk`    | Oracle OpenJDK      |
| `oracle`  | Oracle JDK          |

---

### `jwmv uninstall [candidate] [version]`

Remove an installed SDK version.

```powershell
# Interactive selection
jwmv uninstall

# Remove a specific version
jwmv uninstall 17-zulu
jwmv uninstall gradle 9.5.1
```

**Aliases:** `remove`, `delete`, `rm`

---

### `jwmv installed [candidate]`

List locally installed SDK versions.

```powershell
jwmv installed
jwmv installed java
jwmv installed gradle
```

**Aliases:** `local`

---

### `jwmv use [candidate] <version>`

Activate an SDK for the current shell session. Does **not** modify the persistent default.

```powershell
# Switch to Java 17 for this session
jwmv use 17-zulu

# Switch Gradle for this session
jwmv use gradle 9.5.1

# Specify shell explicitly
jwmv use 21-tem --shell powershell
```

> **Note:** When running as an executable, `use` emits a PowerShell script to stdout. For seamless switching, set up [shell integration](#shell-integration).

| Option           | Description                   |
|------------------|-------------------------------|
| `[candidate]`    | Candidate name, optional for Java shorthand |
| `<version>`      | Version to activate |
| `--shell <SHELL>` | Target shell (default: powershell) |

---

### `jwmv default [candidate] <version>`

Set the persistent default SDK version for all new shell sessions.

```powershell
# Set Java 21 Temurin as the system-wide default
jwmv default 21-tem

# Set Maven as the default
jwmv default maven 3.9.15
```

This updates the Windows **User** environment variables (`JAVA_HOME`, `GRADLE_HOME`, `MAVEN_HOME`, or `KOTLIN_HOME` plus `PATH`) and broadcasts the change so new terminals pick it up immediately.

---

### `jwmv current [candidate]`

Show the currently active SDK versions and how they were resolved.

```powershell
jwmv current
jwmv current java
jwmv current gradle
```

Output shows:
- Candidate and active version alias
- Resolution source: **Default**, **Session**, or **Project**
- Resolved home and `bin` paths
- Project `.jwmvrc` path (if applicable)

---

### `jwmv home [candidate] [version]`

Print the SDK home path for a version. Useful for scripting.

```powershell
# Current JAVA_HOME
jwmv home

# JAVA_HOME for a specific version
jwmv home 17-zulu

# Gradle home for a specific version
jwmv home gradle 9.5.1

# Use in scripts
$env:JAVA_HOME = $(jwmv home 21-tem)
```

---

### `jwmv upgrade [identifier]`

Upgrade installed JDK(s) to the latest patch in the same major/vendor track.

```powershell
# Upgrade a specific installation
jwmv upgrade 21-tem

# Upgrade all installed versions
jwmv upgrade
```

---

### `jwmv update`

Refresh the local catalog cache from all SDK providers.

```powershell
jwmv update
```

The catalog is cached locally and auto-refreshes every 6 hours (configurable). Use this to force an immediate refresh.

---

### `jwmv doctor`

Run diagnostics to detect common issues.

```powershell
jwmv doctor
```

Checks for:
- `JAVA_HOME` correctness
- `PATH` conflicts (e.g. system Java taking precedence)
- PowerShell profile integration status
- `java.exe` resolution via `where.exe`

---

### `jwmv config`

Display the current jwmv configuration.

```powershell
jwmv config
```

Shows: root directory, config file path, preferred distribution, catalog refresh interval, auto-env setting, default shell, and self-update repository.

---

### `jwmv integrate`

Install the PowerShell profile hook for automatic version switching.

```powershell
# Auto-detect profile
jwmv integrate

# Specify shell
jwmv integrate --shell powershell

# Custom profile path
jwmv integrate --profile "C:\Users\me\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
```

| Option              | Description                     |
|---------------------|---------------------------------|
| `--shell <SHELL>`   | Target shell (default: powershell) |
| `--profile <PATH>`  | Custom profile file path        |

---

### `jwmv env`

Print environment activation scripts or show project configuration.

```powershell
# Show project .jwmvrc
jwmv env

# Emit initialization script
jwmv env --init

# Create .jwmvrc from active SDKs
jwmv env init

# Install missing SDKs declared in .jwmvrc
jwmv env install

# Emit for a specific directory
jwmv env --cwd ./my-project
```

| Option           | Description                             |
|------------------|-----------------------------------------|
| `--shell <SHELL>` | Target shell                           |
| `--cwd <PATH>`   | Working directory to scan for .jwmvrc   |
| `--init`          | Emit shell initialization script       |
| `init`            | Create `.jwmvrc` from active SDKs     |
| `install`         | Install missing SDKs from `.jwmvrc`   |

---

### `jwmv flush`

Clear cached files selectively.

```powershell
# Clear downloaded archives
jwmv flush --archives

# Clear temporary files
jwmv flush --temp

# Clear catalog cache
jwmv flush --catalog

# Clear everything
jwmv flush --archives --temp --catalog
```

| Option        | Description                      |
|---------------|----------------------------------|
| `--archives`  | Delete downloaded ZIP archives   |
| `--temp`      | Delete temporary extraction files |
| `--catalog`   | Delete the catalog cache         |

---

### `jwmv selfupdate`

Update jwmv itself from GitHub Releases.

```powershell
# Check for updates
jwmv selfupdate --check

# Apply update
jwmv selfupdate

# Skip confirmation
jwmv selfupdate --yes

# Force reinstall current version
jwmv selfupdate --force

# Update and restart
jwmv selfupdate --restart

# Use a different repository
jwmv selfupdate --repository owner/repo
```

**Aliases:** `self-update`

| Option                    | Description                              |
|---------------------------|------------------------------------------|
| `-c, --check`             | Only check, don't apply                  |
| `-f, --force`             | Force update even if same version        |
| `-y, --yes`               | Skip confirmation prompt                 |
| `--restart`               | Restart jwmv after update                |
| `-r, --repository <REPO>` | GitHub `owner/repo` for releases        |
| `-t, --tag <TAG>`         | Specific release tag to install          |

---

## Shell Integration

jwmv can automatically switch SDK versions when you `cd` into a project with a `.jwmvrc` file.

### Setup

```powershell
jwmv integrate
```

This adds a managed block to your PowerShell profile (`$PROFILE`) that bootstraps jwmv on every new terminal session. The integration:

1. Reads the current or project-specific SDK versions
2. Sets `JAVA_HOME`, `GRADLE_HOME`, `MAVEN_HOME`, `KOTLIN_HOME`, and `PATH` automatically
3. Switches versions seamlessly as you navigate between projects

### Manual integration

Add this to your PowerShell profile (`$PROFILE`):

```powershell
# >>> jwmv initialize >>>
$jwmvInit = & jwmv env --init --shell powershell 2>$null
if ($jwmvInit) { $jwmvInit | Invoke-Expression }
# <<< jwmv initialize <<<
```

---

## Per-Project SDK Versions

Create a `.jwmvrc` file in your project root:

```
java=21-tem
gradle=9.5.1
maven=3.9.15
kotlin=2.3.21
```

Legacy Java-only files containing just `21-tem` are still accepted and treated as `java=21-tem`.

When shell integration is active, jwmv automatically activates these versions when you enter the directory. The resolution order for each candidate is:

1. **Session** — set via `jwmv use`
2. **Project** — from `.jwmvrc` (walks up the directory tree)
3. **Default** — set via `jwmv default`

---

## Configuration

jwmv stores its data under `~/.jwmv/`:

```
~/.jwmv/
├── config.json          # User configuration
├── candidates/
│   ├── java/            # Installed JDKs
│   ├── gradle/
│   ├── maven/
│   └── kotlin/
├── archives/            # Downloaded ZIP files, grouped by candidate
├── tmp/                 # Temporary extraction files
└── var/
    ├── catalog.json     # Legacy cached Foojay catalog
    ├── catalog-v2.json  # Cached multi-SDK catalog
    └── manifests/
        ├── java/        # Installation metadata (one JSON per version)
        ├── gradle/
        ├── maven/
        └── kotlin/
```

### `config.json`

```json
{
  "preferredDistributionAlias": "tem",
  "catalogRefreshHours": 6,
  "autoEnvEnabled": true,
  "defaultShell": "powershell",
  "defaultJavaAlias": "21-tem",
  "defaultVersions": {
    "java": "21-tem",
    "gradle": "9.5.1"
  },
  "selfUpdateRepository": "stescobedo92/jwmv"
}
```

| Key                         | Default        | Description                                  |
|-----------------------------|----------------|----------------------------------------------|
| `preferredDistributionAlias` | `"tem"`        | Default distribution when not specified       |
| `catalogRefreshHours`        | `6`            | Hours before catalog auto-refreshes           |
| `autoEnvEnabled`             | `true`         | Enable `.jwmvrc` auto-switching               |
| `defaultShell`               | `"powershell"` | Shell for script generation                   |
| `defaultJavaAlias`           | —              | Legacy persistent default Java version        |
| `defaultVersions`            | `{}`           | Persistent defaults by SDK candidate          |
| `selfUpdateRepository`       | —              | GitHub `owner/repo` for self-update           |

---

## Usage Examples

### Managing a multi-project workflow

```powershell
# Project A needs Java 17 and Maven
cd ~\examples\legacy-app
@"
java=17-cor
maven=3.9.15
"@ > .jwmvrc

# Project B needs Java 21 and Gradle
cd ~\examples\modern-api
@"
java=21-tem
gradle=9.5.1
"@ > .jwmvrc

# Install required SDKs
jwmv install 17-cor
jwmv install 21-tem --default
jwmv install maven 3.9.15
jwmv install gradle 9.5.1

# With shell integration, SDKs switch automatically
cd ~\examples\legacy-app
java -version   # → Corretto 17
mvn -version    # → Maven 3.9.15

cd ~\examples\modern-api
java -version   # → Temurin 21
gradle -version # → Gradle 9.5.1
```
---

## Architecture

```
Jwmv.Cli            → Spectre.Console CLI commands and DI setup
Jwmv.Core            → Interfaces, models, utilities (no dependencies)
Jwmv.Infrastructure  → SDK catalog providers, storage, Windows integration
Jwmv.Tests           → XUnit tests
```

The project follows a clean architecture pattern with dependency inversion. All services are behind interfaces and injected via `Microsoft.Extensions.DependencyInjection`.

---

## License

This project is open source. See the repository for license details.
