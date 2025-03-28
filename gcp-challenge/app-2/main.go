package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"text/template"

	"example.com/app-2/html"
	"example.com/app-2/message"
	"google.golang.org/api/idtoken"
)

// PubSubMessage is the payload of a Pub/Sub event
type PubSubMessage struct {
	Message struct {
		Data string `json:"data"`
	} `json:"message"`
	Subscription string `json:"subscription"`
}

// Replace the global variable with the new type
var store = message.NewStore(5)

// Add a function to validate messages with the publisher app
func validateWithPublisher(randomValue string) (bool, error) {
	// Make IAP request to publisher app to validate
	publisherURL := os.Getenv("PUBLISHER_APP_URL")
	audience := os.Getenv("PUBLISHER_APP_IAP_CLIENT_ID")

	// Create a new request to the publisher app
	httpReq, err := http.NewRequest("GET", publisherURL+"/validate?randomValue="+randomValue, nil)
	if err != nil {
		return false, fmt.Errorf("failed to create request: %w", err)
	}
	httpReq.Header.Set("Content-Type", "application/json")

	// Make the request to the publisher app using IAP helper to add auth header
	var validationResponse bytes.Buffer
	if err := makeIAPRequest(&validationResponse, httpReq, audience); err != nil {
		return false, fmt.Errorf("failed to validate with publisher using IAP helper: %w", err)
	}

	var result struct {
		RecentlyPublished bool `json:"recentlyPublished"`
	}
	if err := json.NewDecoder(&validationResponse).Decode(&result); err != nil {
		return false, fmt.Errorf("failed to decode validation response: %w", err)
	}

	return result.RecentlyPublished, nil
}

func handlePubSubMessage(w http.ResponseWriter, r *http.Request) {
	// Parse the incoming message
	var m PubSubMessage
	if err := json.NewDecoder(r.Body).Decode(&m); err != nil {
		http.Error(w, fmt.Sprintf("Error parsing message: %v", err), http.StatusBadRequest)
		return
	}

	// Decode the base64 encoded data
	randomValueBytes, err := base64.StdEncoding.DecodeString(m.Message.Data)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error decoding message data: %v", err), http.StatusBadRequest)
		return
	}
	randomValue := string(randomValueBytes)

	// Validate the message with the publisher
	validated, err := validateWithPublisher(randomValue)
	if err != nil {
		log.Printf("Error validating message: %v", err)
		http.Error(w, fmt.Sprintf("Error validating message: %v", err), http.StatusInternalServerError)
		return
	}

	// Store the message for display in the UI
	store.AddMessage(message.New(randomValue, validated))

	w.WriteHeader(http.StatusOK)
}

// Add a simple HTML form for the UI
func handleHome(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get current messages from the store
	messages := store.GetMessages()

	// Create template
	tmpl, err := template.New("home").Parse(html.Template)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error parsing template: %v", err), http.StatusInternalServerError)
		return
	}

	// Set content type and execute template
	w.Header().Set("Content-Type", "text/html")
	if err := tmpl.Execute(w, messages); err != nil {
		http.Error(w, fmt.Sprintf("Error executing template: %v", err), http.StatusInternalServerError)
		return
	}
}

// makeIAPRequest makes a request to an application protected by Identity-Aware
// Proxy with the given audience. The audience should be the IAP client ID.
func makeIAPRequest(w io.Writer, request *http.Request, audience string) error {
	ctx := context.Background()

	// client is a http.Client that automatically adds an "Authorization" header
	// to any requests made.
	client, err := idtoken.NewClient(ctx, audience)
	if err != nil {
		return fmt.Errorf("idtoken.NewClient: %w", err)
	}

	response, err := client.Do(request)
	if err != nil {
		return fmt.Errorf("client.Do: %w", err)
	}
	defer response.Body.Close()
	if _, err := io.Copy(w, response.Body); err != nil {
		return fmt.Errorf("io.Copy: %w", err)
	}

	return nil
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", handleHome)
	http.HandleFunc("/pubsub", handlePubSubMessage)

	log.Printf("Starting server on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
