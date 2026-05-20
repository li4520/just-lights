# Contributing

Thanks for taking a look at Just Lights.

## Development

- Keep the app focused on ANT+ bike-light mode control.
- Do not add radar alerts, vehicle detection, proximity warnings, incident detection, or other safety-awareness behavior.
- Keep generated files out of git. Build outputs belong under `build/`.
- Run the relevant unit-test build before opening a pull request:

```bash
CIQ_DEVELOPER_KEY=/path/to/developer_key scripts/test.sh --build-only edge1050
```

If you change shared light-mode behavior, also run the simulator tests when available:

```bash
CIQ_DEVELOPER_KEY=/path/to/developer_key scripts/test.sh edge1050
```

## Compatibility Notes

When reporting a light compatibility result, include:

- Edge model
- Connect IQ SDK version if built from source
- Light model
- Supported modes shown by the app
- Which commands worked or failed

Do not include private developer keys, debug signing material, or personally identifying ride data.
