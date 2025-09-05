# Vendored Dependencies

This directory contains vendored dependencies so linenoize can be built offline without any network access.

## wcwidth

- **Source**: https://github.com/joachimschmidt557/zig-wcwidth
- **Version**: commit 2c9a874 (v0.1.0 + Zig 0.15.x fixes)
- **License**: MIT
- **Purpose**: Unicode character width calculation

### Updating wcwidth

To update the vendored wcwidth:
```bash
# Clone the latest version
git clone https://github.com/joachimschmidt557/zig-wcwidth /tmp/zig-wcwidth
cd /tmp/zig-wcwidth

# Copy the source files
cp -r src /path/to/linenoize/vendor/wcwidth/
```

No network dependencies required for building - perfect for private jets! ✈️