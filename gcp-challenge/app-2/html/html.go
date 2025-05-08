package html

const Template = `
<!DOCTYPE html>
<html>
<head>
    <title>Subscriber App</title>
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
        .validate-form {
            background-color: white;
            padding: 15px;
            border-radius: 4px;
            margin-bottom: 20px;
            border: 1px solid #ddd;
        }
        .form-group {
            margin-bottom: 15px;
        }
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        .form-group input {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
        }
        .validate-button {
            background-color: #007bff;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
        }
        .validate-button:hover {
            background-color: #0056b3;
        }
        .result {
            margin-top: 10px;
            padding: 10px;
            border-radius: 4px;
        }
        .success {
            background-color: #dff0d8;
            border: 1px solid #d6e9c6;
            color: #3c763d;
        }
        .error {
            background-color: #f2dede;
            border: 1px solid #ebccd1;
            color: #a94442;
        }
        .validation {
            margin-left: 10px;
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 0.8em;
        }
        .validation.success {
            background-color: #dff0d8;
            color: #3c763d;
        }
        .validation.error {
            background-color: #f2dede;
            color: #a94442;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Subscriber App</h1>
            <h2>Received Messages</h2>
        </div>

        {{range .}}
        <div class="message">
            <div class="content">Random Value: {{.RandomValue}}</div>
            <div class="message-id">
                Received: {{.ReceivedAt.Format "2006-01-02 15:04:05"}}
                {{if .Validated}}
                    <span class="validation success">Validated by Publisher App</span>
                {{else}}
                    <span class="validation error">Failed Validation by Publisher App</span>
                {{end}}
            </div>
        </div>
        {{else}}
        <p>No messages received yet.</p>
        {{end}}
    </div>
</body>
</html>
`
