#!/bin/bash

# Watch frontend/build/index.js for changes using bunx chokidar-cli
bunx chokidar-cli "frontend/build/index.js" -c "curl -s http://localhost:7021/refresh || echo 'Failed to send refresh request'"
