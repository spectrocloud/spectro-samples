package main

import (
	"context"
	"encoding/json"
	"html/template"
	"log"
	"net/http"
	"os"

	"cloud.google.com/go/pubsub"
	"example.com/app-1/html"
)

var (
	topic     *pubsub.Topic
	topicID   string
	projectID string
)

func handleHome(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	tmpl, err := template.New("home").Parse(html.Template)
	if err != nil {
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html")
	tmpl.Execute(w, nil)
}

func handlePublish(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var msg struct {
		Data string `json:"data"`
	}
	if err := json.NewDecoder(r.Body).Decode(&msg); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	ctx := context.Background()
	result := topic.Publish(ctx, &pubsub.Message{
		Data: []byte(msg.Data),
	})

	// Wait for the publish operation to complete
	id, err := result.Get(ctx)
	if err != nil {
		response := map[string]string{"error": err.Error()}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(response)
		return
	}

	// Return the published message ID
	response := map[string]string{"messageId": id}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
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
	http.HandleFunc("/publish", handlePublish)

	log.Printf("Starting server on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
