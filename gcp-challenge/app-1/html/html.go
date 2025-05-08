package html

const Template = `
<!DOCTYPE html>
<html>
<head>
    <title>Publisher App</title>
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
        .form-group {
            margin-bottom: 15px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        textarea {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
            min-height: 100px;
            font-family: inherit;
        }
        button {
            background-color:rgb(76, 175, 84);
            color: white;
            padding: 10px 20px;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        button:hover {
            background-color: #45a049;
        }
        .result {
            margin-top: 20px;
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
    </style>
</head>
<body>
    <div class="container">
        <h1>Publisher App</h1>
        <form method="POST" id="messageForm">
            <p>Upon clicking publish, a random value will be generated and published to the Subscriber App.</p>
            <button type="submit">Publish Message</button>
        </form>
        <div id="publishResult" class="result" style="display: none;"></div>

        <form id="validateForm" style="margin-top: 20px;">
            <div class="form-group">
                <label for="validateValue">Validate Random Value:</label>
                <input type="text" id="validateValue" name="validateValue" required>
            </div>
            <button type="submit">Validate Message</button>
        </form>
        <div id="validateResult" class="result" style="display: none;"></div>
    </div>
    <script>
        document.getElementById('messageForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const resultDiv = document.getElementById('publishResult');
            
            try {
                const response = await fetch('/whisper', {
                    method: 'POST',
                });
                
                const result = await response.json();
                if (response.ok) {
                    resultDiv.className = 'result success';
                    resultDiv.textContent = 'Message published successfully! Random Value: ' + result.randomValue;
                } else {
                    resultDiv.className = 'result error';
                    resultDiv.textContent = 'Error: ' + result.error;
                }
            } catch (error) {
                resultDiv.className = 'result error';
                resultDiv.textContent = 'Error: ' + error.message;
            }
            
            resultDiv.style.display = 'block';
        });

        document.getElementById('validateForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const resultDiv = document.getElementById('validateResult');
            const validateValue = document.getElementById('validateValue').value;
            
            try {
                const response = await fetch('/validate?randomValue=' + encodeURIComponent(validateValue), {
                    method: 'GET',
                });
                
                const result = await response.json();
                if (response.ok) {
                    resultDiv.className = 'result ' + (result.recentlyPublished ? 'success' : 'error');
                    resultDiv.textContent = result.recentlyPublished ? 
                        "Message with random value " + validateValue + " was recently published!" : 
                        "Message with random value " + validateValue + " was not recently published.";
                } else {
                    resultDiv.className = 'result error';
                    resultDiv.textContent = 'Error: ' + result.error;
                }
            } catch (error) {
                resultDiv.className = 'result error';
                resultDiv.textContent = 'Error: ' + error.message;
            }
            
            resultDiv.style.display = 'block';
        });
    </script>
</body>
</html>
`
