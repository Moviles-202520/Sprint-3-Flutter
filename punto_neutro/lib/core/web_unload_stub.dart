// Fallback for non-web platforms; no-op registrations
void registerBeforeUnload(void Function() onUnload) {}
void unregisterBeforeUnload() {}