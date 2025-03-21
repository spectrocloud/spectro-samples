package html

const Template = `
<!DOCTYPE html>
<html>
<head>
    <title>Received Messages</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        .container {
            background-color: #f5f5f5;
            border-radius: 8px;
            padding: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .message {
            background-color: white;
            border: 1px solid #ddd;
            border-radius: 4px;
            padding: 10px;
            margin-bottom: 10px;
        }
        .message-id {
            color: #666;
            font-size: 0.8em;
            margin-top: 8px;
            padding-top: 8px;
            border-top: 1px solid #eee;
        }
        h1 {
            color: #333;
            margin-bottom: 20px;
        }
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 20px;
        }
        .clear-button {
            background-color: #dc3545;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
        }
        .clear-button:hover {
            background-color: #c82333;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Received Messages</h1>
            <button class="clear-button" onclick="clearMessages()">Clear Messages</button>
        </div>
        {{range .}}
        <div class="message">
            <div class="content">{{.Content}}</div>
            <div class="message-id">Message ID: {{.ID}}</div>
        </div>
        {{else}}
        <p>No messages received yet.</p>
        {{end}}
    </div>
    <script>
        function clearMessages() {
            fetch('/clear', { method: 'POST' })
                .then(response => {
                    if (response.ok) {
                        window.location.reload();
                    } else {
                        alert('Failed to clear messages');
                    }
                })
                .catch(error => {
                    console.error('Error:', error);
                    alert('Failed to clear messages');
                });
        }
    </script>
</body>
</html>
`
