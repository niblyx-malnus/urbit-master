# master

**Experimental** Urbit desk providing MCP (Model Context Protocol) integration and cloud services. A "super app" designed for LLM interaction - features are still being discovered and developed.

## What It Does

Exposes capabilities to AI assistants via MCP:
- Send Telegram notifications
- Manage S3/cloud storage
- Query Claude AI and Brave Search
- Access ship utilities (time, random, naming)

Think of it as an API layer between LLMs and your Urbit ship + external services.

## Quick Start

```bash
# Install desk to ship
./sync.sh

# In dojo
|mount %master
|commit %master
|install our %master

# Configure
cp config.example.json config.json
nano config.json
./urbit-master update all
```

## Management

```bash
./urbit-master status       # Check connectivity
./urbit-master update all   # Update credentials
./urbit-master test mcp     # Test MCP endpoint
./urbit-master help         # Full commands
```

See [URBIT-MASTER.md](URBIT-MASTER.md) for CLI details.

## Structure

```
master/
├── desk/                  # Urbit desk files
├── urbit-master          # CLI management tool
├── scripts/              # CLI libraries
├── config.json           # Your credentials (gitignored)
└── sync.sh               # Development sync
```

## MCP Integration

The desk runs an MCP server at `/master/mcp` that AI assistants can call to:
- Send messages (Telegram)
- Store/retrieve files (S3)
- Query external APIs
- Access ship data

Still discovering what's useful - this is an experiment in giving LLMs structured access to Urbit and external services.

## Configuration

Required in `config.json`:
- `ship_url` and `access_code` - Your ship
- `telegram` - Bot token and chat ID
- `s3` - Storage credentials
- `claude` - API key
- `brave` - Search API key

See `config.example.json` for template.

## Development Status

**Experimental** - Active development, features being added as useful patterns emerge. Not production-ready.

Current capabilities:
- ✅ MCP server implementation
- ✅ Telegram notifications
- ✅ S3 storage integration
- ✅ Claude AI queries
- ✅ Brave Search queries
- 🚧 Additional tools TBD

## Security

- `config.json` is gitignored
- No secrets logged or echoed
- Ship authentication via secure cookies
- Review `.gitignore` before committing

## Documentation

- [URBIT-MASTER.md](URBIT-MASTER.md) - CLI documentation
- `config.example.json` - Configuration template
- `./urbit-master help` - Command reference
