package main

import (
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"math/rand"
	"net/http"
	"os"

	"encoding/hex"

	"cloud.google.com/go/pubsub"
	"example.com/app-1/html"
	"example.com/app-1/message"
)

var (
	topic     *pubsub.Topic
	topicID   string
	projectID string

	messageStore = message.NewStore(5)
)

// Displays a home page with the messages published so far.
func handleHome(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	tmpl, err := template.New("home").Parse(html.Template)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error parsing template: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html")
	tmpl.Execute(w, nil)
}

// Generates a random value and publishes it to Pub/Sub.
func handleWhisper(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Generate random value
	randomBytes := make([]byte, 16)
	if _, err := rand.Read(randomBytes); err != nil {
		http.Error(w, fmt.Sprintf("Failed to generate random value: %v", err), http.StatusInternalServerError)
		return
	}
	fullHex := hex.EncodeToString(randomBytes)
	randomValue := fullHex[len(fullHex)-4:] // Keep only last 4 characters

	// Store the message for validation later
	messageStore.AddMessage(randomValue)

	// Publish to Pub/Sub
	ctx := context.Background()
	msg := &pubsub.Message{
		Data: []byte(randomValue),
	}
	result := topic.Publish(ctx, msg)
	if _, err := result.Get(ctx); err != nil {
		http.Error(w, fmt.Sprintf("Failed to publish message: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"randomValue": randomValue,
	})
}

// Validates that a message with a particular random value was published.
func handleValidate(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Get random value to check from query string parameter
	randomValue := r.URL.Query().Get("randomValue")
	if randomValue == "" {
		http.Error(w, "Missing randomValue parameter", http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"recentlyPublished": messageStore.HasMessage(randomValue),
	})
}

func main() {
	var err error
	projectID = os.Getenv("PROJECT_ID")
	if projectID == "" {
		log.Fatal("PROJECT_ID environment variable must be set")
	}

	topicID = os.Getenv("PUBSUB_TOPIC")
	if topicID == "" {
		log.Fatal("PUBSUB_TOPIC environment variable must be set")
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	ctx := context.Background()
	client, err := pubsub.NewClient(ctx, projectID)
	if err != nil {
		log.Fatalf("Failed to create pubsub client: %v", err)
	}
	defer client.Close()

	topic = client.Topic(topicID)

	// Verify the topic exists
	exists, err := topic.Exists(ctx)
	if err != nil {
		log.Fatalf("Failed to check if topic exists: %v", err)
	}
	if !exists {
		log.Fatalf("Topic %s does not exist", topicID)
	}

	http.HandleFunc("/", handleHome)
	http.HandleFunc("/whisper", handleWhisper)
	http.HandleFunc("/validate", handleValidate)

	log.Printf("Starting server on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
