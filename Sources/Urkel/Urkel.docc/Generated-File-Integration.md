# Generated File Integration

The safest Urkel integration pattern is to treat generated Swift as read-only and place custom behavior in sidecar files next to it.

## Recommended layout

- `Sources/MyFeature/MyFeature.urkel`
- `Sources/MyFeature/myfeature+Generated.swift`
- `Sources/MyFeature/MyFeatureClient+Runtime.swift`
- `Sources/MyFeature/MyFeatureClient+Live.swift`
- `Sources/MyFeature/MyFeatureClient+Test.swift`

## Integration rules

- Never manually edit the generated file.
- Keep all runtime specifics in sidecars.
- Refer to namespaced state markers (`MachineMachine.Idle`, `MachineMachine.Running`, `MachineMachine.Stopped`).
- When the machine uses typed context, keep the sidecar context bridge aligned with the generated runtime shape.

## Migration checklist

1. Regenerate the generated file.
2. Fix compiler errors in the sidecars.
3. Re-run the package tests.
4. Only then consider the integration complete.

If you need to customize the generated output, add a `.urkel-config.json` file next to the machine definition and set `template`, `language`, `outputExtension`, or `outputDirectory` there instead of editing the generated file by hand.
