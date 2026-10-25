0.5.0

Removed all VRAM usage. Systems with a dedicated graphics card will now have a truly idle gpu.
Servers without a graphics device now use over 1 GiB less RAM, a 53% reduction compared to 0.4.0
New bug, Unity.BatchModeWindow (supposedly i think) opens as a blank screen. We are now hiding it when it appears but there will be a flash of a window  