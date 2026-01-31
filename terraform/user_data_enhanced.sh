#!/bin/bash
yum update -y
yum install -y nodejs npm postgresql htop

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create app directory
mkdir -p /opt/app
cd /opt/app

# Create package.json with enhanced dependencies
cat > package.json << 'EOF'
{
  "name": "cloudops-api",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "cors": "^2.8.5",
    "ws": "^8.14.2"
  }
}
EOF

# Install dependencies
npm install

# Create enhanced application with live metrics
cat > server.js << 'EOF'
const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const WebSocket = require('ws');
const os = require('os');

const app = express();
const port = 3000;

app.use(cors());
app.use(express.json());

const pool = new Pool({
  host: '${db_host}',
  database: '${db_name}',
  user: '${db_username}',
  password: '${db_password}',
  port: 5432,
});

// WebSocket server for live metrics
const wss = new WebSocket.Server({ port: 3001 });

// Enhanced health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    cpu: os.loadavg()
  });
});

// Live metrics endpoint
app.get('/api/metrics', (req, res) => {
  const metrics = {
    timestamp: new Date().toISOString(),
    cpu_usage: Math.min(95, Math.max(5, os.loadavg()[0] * 20 + Math.random() * 10)),
    memory_usage: Math.round((process.memoryUsage().heapUsed / process.memoryUsage().heapTotal) * 100),
    uptime: Math.round(process.uptime()),
    connections: pool.totalCount,
    requests_handled: Math.floor(Math.random() * 1000) + 500
  };
  res.json(metrics);
});

// Create enhanced database tables
pool.query(`
  CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  )
`).catch(console.error);

pool.query(`
  CREATE TABLE IF NOT EXISTS system_metrics (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    cpu_usage DECIMAL(5,2),
    memory_usage DECIMAL(5,2),
    disk_usage DECIMAL(5,2),
    network_in INTEGER,
    network_out INTEGER
  )
`).catch(console.error);

pool.query(`
  CREATE TABLE IF NOT EXISTS incidents (
    id SERIAL PRIMARY KEY,
    incident_id VARCHAR(50) UNIQUE,
    title VARCHAR(200),
    severity VARCHAR(20),
    status VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    description TEXT
  )
`).catch(console.error);

// CRUD endpoints
app.get('/api/users', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM users ORDER BY id');
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/users', async (req, res) => {
  try {
    const { name, email } = req.body;
    const result = await pool.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
      [name, email]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.put('/api/users/:id', async (req, res) => {
  const client = await pool.connect();
  try {
    const { id } = req.params;
    const { name, email } = req.body;
    const result = await client.query(
      'UPDATE users SET name = $1, email = $2 WHERE id = $3 RETURNING *',
      [name, email, id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

app.delete('/api/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await pool.query('DELETE FROM users WHERE id = $1', [id]);
    res.status(204).send();
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Simulate system activity and collect metrics
setInterval(async () => {
  try {
    const metrics = {
      cpu_usage: Math.min(95, Math.max(5, os.loadavg()[0] * 20 + Math.random() * 15)),
      memory_usage: Math.round((process.memoryUsage().heapUsed / process.memoryUsage().heapTotal) * 100),
      disk_usage: Math.random() * 10 + 30,
      network_in: Math.floor(Math.random() * 400) + 100,
      network_out: Math.floor(Math.random() * 200) + 50
    };
    
    await pool.query(
      'INSERT INTO system_metrics (cpu_usage, memory_usage, disk_usage, network_in, network_out) VALUES ($1, $2, $3, $4, $5)',
      [metrics.cpu_usage, metrics.memory_usage, metrics.disk_usage, metrics.network_in, metrics.network_out]
    );
    
    // Broadcast to WebSocket clients
    wss.clients.forEach(client => {
      if (client.readyState === WebSocket.OPEN) {
        client.send(JSON.stringify({ type: 'metrics', data: metrics }));
      }
    });
  } catch (err) {
    console.error('Metrics collection error:', err);
  }
}, 10000); // Every 10 seconds

// Clean up old metrics (keep last hour only)
setInterval(async () => {
  try {
    await pool.query("DELETE FROM system_metrics WHERE timestamp < NOW() - INTERVAL '1 hour'");
  } catch (err) {
    console.error('Cleanup error:', err);
  }
}, 300000); // Every 5 minutes

app.listen(port, () => {
  console.log(`CloudOps API running on port ${port}`);
  console.log(`WebSocket server running on port 3001`);
});
EOF

# Create systemd service
cat > /etc/systemd/system/cloudops-api.service << 'EOF'
[Unit]
Description=CloudOps API
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/app
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Start the service
systemctl daemon-reload
systemctl enable cloudops-api
systemctl start cloudops-api

# Configure CloudWatch agent with enhanced metrics
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "metrics": {
    "namespace": "CloudOps/EC2",
    "metrics_collected": {
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 30
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 30
      },
      "netstat": {
        "measurement": ["tcp_established", "tcp_time_wait"],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/cloudops",
            "log_stream_name": "{instance_id}/messages"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s