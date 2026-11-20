# SteamOS performance profile default

## Supported control path

SteamOS exposes a `PerformanceProfile1` interface through SteamOS Manager. The `steamosctl` CLI includes:

```bash
steamosctl get-performance-profile
steamosctl set-performance-profile performance
```

Use this manager API rather than writing CPU governor, TDP, GPU clock, or platform-profile sysfs nodes directly. Steam Client and SteamOS Manager coordinate these settings, and bypassing the manager can leave the UI and actual hardware state out of sync.

SteamOS Manager has a session-bus daemon and a privileged system-bus daemon. The session-side manager is tied into the Gamescope session. A boot-time system service that calls the CLI without the correct user bus/session context is therefore not an acceptable implementation.

## Persistence requirement

The setter is a runtime control. This project has not yet verified that calling it persists the default across reboot or that Steam Client will not subsequently restore the user's previous profile. Do not claim that a one-shot `steamosctl set-performance-profile performance` call configures a persistent default.

Before adding an installer service or modifying user settings, validate on SteamOS 3.10:

1. Which Steam Client/SteamOS Manager setting stores the default profile.
2. Whether the setting is per-user, per-session, or global.
3. The ordering of Steam Client profile restoration relative to the Gamescope session and manager startup.
4. Whether the profile survives reboot, suspend/resume, AC/battery transitions, and manual QAM changes.
5. How the installer can set the requested default while preserving the user's ability to change it later.

Once confirmed, implement this as a user-session integration that calls the supported manager API and does not modify kernel sysfs state directly.
