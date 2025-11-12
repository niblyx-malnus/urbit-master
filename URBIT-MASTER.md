# urbit-master

A secure, unified CLI tool for managing your Urbit master desk. Handles credential updates, endpoint testing, and ship interactions through a single command-line interface.

## Features

- **Unified CLI**: Single entry point for all master desk operations
- **Security-First**: Never logs or echoes secrets, uses secure temp files, automatic cleanup
- **Credential Management**: Update Telegram, S3, Claude, and Brave Search credentials
- **Testing Suite**: Test all endpoints (S3, MCP, Claude, web search)
- **Status Monitoring**: Check ship connectivity and authentication
- **Clean Architecture**: Modular library structure for easy maintenance

## Quick Start

### 1. Setup Configuration

```bash
# Copy the example config
cp config.example.json config.json

# Edit with your credentials
nano config.json
```

Fill in your values:
- `ship_url`: Your Urbit ship URL (e.g., `http://localhost:8080`)
- `access_code`: Your ship's access code
- Service credentials: Telegram, S3, Claude API, Brave Search

### 2. Install Dependencies

```bash
# Required
sudo apt-get install jq curl  # Ubuntu/Debian
brew install jq curl          # macOS

# Optional (for sync.sh)
sudo apt-get install fswatch  # Ubuntu/Debian
brew install fswatch          # macOS
```

### 3. Run Commands

```bash
# Check ship status
./urbit-master status

# Update all credentials
./urbit-master update all

# Update specific service
./urbit-master update telegram

# Test S3 upload
./urbit-master test s3-upload "Hello World" "test.txt"

# Test MCP
./urbit-master test mcp tools/list

# Get help
./urbit-master help
```

## Usage

### Update Commands

Update service credentials from config.json:

```bash
./urbit-master update telegram    # Update Telegram bot credentials
./urbit-master update s3           # Update S3/Spaces credentials
./urbit-master update claude       # Update Claude API key
./urbit-master update brave        # Update Brave Search API key
./urbit-master update all          # Update all configured services
```

### Test Commands

Test various endpoints:

```bash
# S3 Tests
./urbit-master test s3-upload [text] [filename]
./urbit-master test s3-upload-dir [directory] [prefix]
./urbit-master test s3-get [filename]
./urbit-master test s3-get-dir [prefix]
./urbit-master test s3-list [prefix]
./urbit-master test s3-delete [filename]

# API Tests
./urbit-master test claude [prompt]
./urbit-master test claude-mcp [prompt]
./urbit-master test web-search [query]

# MCP Tests
./urbit-master test mcp initialize
./urbit-master test mcp tools/list
./urbit-master test mcp send_telegram "Your message"
```

### Other Commands

```bash
./urbit-master status     # Check ship connectivity
./urbit-master version    # Show version
./urbit-master help       # Show help
```

## Project Structure

```
urbit-master/
├── urbit-master           # Main CLI entry point
├── scripts/               # Library modules
│   ├── core.sh           # Auth, config, HTTP helpers, logging
│   ├── credentials.sh    # Credential update functions
│   └── testing.sh        # Test functions
├── config.json           # Your configuration (gitignored)
├── config.example.json   # Configuration template
├── .env                  # Optional env vars (gitignored)
├── .env.example          # Environment template
├── .gitignore            # Git ignore rules
├── URBIT-MASTER.md       # This file (CLI documentation)
├── README.md             # Desk overview
├── sync.sh               # Desk sync utility
└── desk/                 # Urbit desk files
```

## Configuration

### config.json

Main configuration file (gitignored):

```json
{
  "ship_url": "http://localhost:8080",
  "access_code": "your-access-code",
  "telegram": {
    "bot_token": "123456789:ABCdefGHIjklMNOpqrsTUVwxyz",
    "chat_id": "987654321"
  },
  "s3": {
    "access_key": "DO00XXXXXXXXXX",
    "secret_key": "your-secret-key-here",
    "region": "nyc3",
    "bucket": "your-bucket-name",
    "endpoint": "nyc3.digitaloceanspaces.com"
  },
  "claude": {
    "api_key": "sk-ant-..."
  },
  "brave": {
    "api_key": "BSA..."
  },
  "dest": "/path/to/your/ship/master/",
  "resources": {
    "docs": "/path/to/docs.urbit.org/"
  }
}
```

### .env (Optional)

Additional environment variables:

```bash
# Override config location
CONFIG_FILE=/custom/path/config.json

# Enable debug logging
DEBUG=1
```

## Security Features

### No Secret Leakage
- **Never logs credentials**: All logging functions skip secret values
- **No echo/print**: Credentials are never echoed to stdout
- **Secure curl**: No `-v` flag with passwords, uses data encoding

### Secure Temp Files
- **mktemp**: Uses secure temp file creation with random names
- **chmod 600**: Cookie files have strict permissions
- **Auto cleanup**: Trap handlers remove temp files on exit

### Git Safety
- **.gitignore**: config.json and .env are automatically excluded
- **Templates**: .example files show structure without secrets

## Development

### Adding New Commands

1. **Add function** to appropriate library:
   - `scripts/credentials.sh` for credential updates
   - `scripts/testing.sh` for test commands
   - `scripts/core.sh` for core utilities

2. **Update CLI router** in `urbit-master`:
   - Add case statement entry
   - Update help text

3. **Update documentation** in URBIT-MASTER.md

### Debug Mode

Enable verbose logging:

```bash
DEBUG=1 ./urbit-master test s3-upload
```

### Testing Changes

```bash
# Test status
./urbit-master status

# Test non-destructive read operations
./urbit-master test s3-list
./urbit-master test mcp tools/list

# Test with sample data
./urbit-master test s3-upload "test content" "test-file.txt"
```

## sync.sh - Desk Synchronization

The `sync.sh` script provides continuous filesystem watching:

```bash
# Start watching and syncing desk/ to your ship
./sync.sh
```

This uses `fswatch` to monitor changes and `rsync` to sync them automatically.

## Troubleshooting

### Authentication Failed
```bash
# Check ship is running
./urbit-master status

# Verify config
cat config.json | jq '.ship_url, .access_code'

# Check ship access in browser
curl http://localhost:8080
```

### Command Not Found
```bash
# Make sure it's executable
chmod +x urbit-master

# Run from project directory
cd ~/Projects/urbit/master
./urbit-master help
```

### jq Not Found
```bash
# Install jq
sudo apt-get install jq      # Ubuntu/Debian
brew install jq              # macOS
```

### Config File Not Found
```bash
# Copy from example
cp config.example.json config.json

# Edit with your values
nano config.json
```

## Best Practices

1. **Never commit secrets**: config.json and .env are gitignored
2. **Test before production**: Use test commands to verify before live use
3. **Keep config backup**: Store config.json securely outside repo
4. **Update regularly**: Keep credentials rotated and fresh
5. **Use debug mode**: Enable DEBUG=1 when troubleshooting

## Examples

### Common Workflows

```bash
# Initial setup
cp config.example.json config.json
nano config.json
./urbit-master status
./urbit-master update all

# Daily use
./urbit-master test mcp tools/list
./urbit-master test s3-list

# Development workflow
./sync.sh &  # Start watching for changes
# Edit files in desk/
# Changes sync automatically

# Update credentials after rotation
./urbit-master update telegram
./urbit-master update s3
```

## Support

- Check `./urbit-master help` for command reference
- Review this document for configuration details
- Examine `scripts/*.sh` for implementation details
