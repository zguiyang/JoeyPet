# App Lifecycle

JoeyPet keeps the pet panel alive independently from the main SwiftUI window.
The app starts quietly with Joey visible; it does not open the main window at
login. The window controller owns one reusable Main Window and brings it to the
front when the context menu opens it. Closing that window leaves Joey running;
only Quit stops the app.

The current activation policy is regular, so the Dock icon remains visible in
this MVP; no separate Dock/lifecycle redesign is part of the phase.

The pet panel restores its last user-dragged origin from UserDefaults using a
screen identifier and normalized position within that screen's visible frame.
Ambient movement is temporary and is never persisted. If the saved display is
gone or the restored frame is fully off-screen, Joey uses the current main
screen's lower-right safe default. Reset Joey Position clears the saved record.

Settings use UserDefaults / `@AppStorage`: Ambient Behaviors and Proactive
Bubbles default to on, while Launch JoeyPet at Login reflects the real
`SMAppService.mainApp` registration and defaults to off when unregistered.

On termination, sensors, the ambient scheduler, the pet runtime, bubbles, and
active cleanup operations are stopped or cancelled. Cleanup persists only the
last execution summary (time, counts, and processed bytes), never the candidate
path list; the next session starts with no cached scan list.
