package main

import (
	"encoding/base64"
	"encoding/json"
	"html/template"
	"log"
	"net/http"
	"os"
	"sync"

	"example.com/app-2/html"
)

// PubSubMessage is the payload of a Pub/Sub event
type PubSubMessage struct {
	Message struct {
		Data string `json:"data"`
		ID   string `json:"messageId"`
	} `json:"message"`
	Subscription string `json:"subscription"`
}

// Message represents a single message with its metadata
type Message struct {
	Content string
	ID      string
}

// MessageStore handles storage of received messages
type MessageStore struct {
	messages []Message
	mu       sync.RWMutex
	maxSize  int
}

// NewMessageStore creates a new MessageStore with specified capacity
func NewMessageStore(capacity int) *MessageStore {
	return &MessageStore{
		messages: make([]Message, 0, capacity),
		maxSize:  capacity,
	}
}

var store = NewMessageStore(5)

func handleMessages(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	store.mu.RLock()
	messages := make([]Message, len(store.messages))
	copy(messages, store.messages)
	store.mu.RUnlock()

	tmpl, err := template.New("messages").Parse(html.Template)
	if err != nil {
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html")
	tmpl.Execute(w, messages)
}

func handlePubSub(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var msg PubSubMessage
	if err := json.NewDecoder(r.Body).Decode(&msg); err != nil {
		http.Error(w, "Bad Request: Invalid JSON", http.StatusBadRequest)
		return
	}

	// Decode the base64-encoded message data
	data, err := base64.StdEncoding.DecodeString(msg.Message.Data)
	if err != nil {
		http.Error(w, "Bad Request: Invalid base64 data", http.StatusBadRequest)
		return
	}

	store.mu.Lock()
	store.messages = append(store.messages, Message{
		Content: string(data),
		ID:      msg.Message.ID,
	})

	// Remove oldest messages if we exceed capacity
	if len(store.messages) > store.maxSize {
		store.messages = store.messages[1:]
	}
	store.mu.Unlock()

	// Acknowledge the message by returning 2xx status
	w.WriteHeader(http.StatusOK)
}

func handleClear(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	store.mu.Lock()
	store.messages = make([]Message, 0, store.maxSize)
	store.mu.Unlock()

	w.WriteHeader(http.StatusOK)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", handleMessages)
	http.HandleFunc("/pubsub", handlePubSub)
	http.HandleFunc("/clear", handleClear)

	log.Printf("Starting server on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
