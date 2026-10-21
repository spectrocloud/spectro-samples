package message

import (
	"sync"
	"time"
)

// Message represents a single message with its metadata
type Message struct {
	Content   string
	Timestamp time.Time
}

// Store handles storage of sent messages
type Store struct {
	messages []Message
	mu       sync.RWMutex
	maxSize  int
}

// NewMessageStore creates a new Store with specified capacity
func NewStore(capacity int) *Store {
	return &Store{
		messages: make([]Message, 0, capacity),
		maxSize:  capacity,
	}
}

// AddMessage adds a new message to the store
func (s *Store) AddMessage(content string) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.messages = append(s.messages, Message{
		Content:   content,
		Timestamp: time.Now(),
	})

	if len(s.messages) > s.maxSize {
		s.messages = s.messages[len(s.messages)-s.maxSize:]
	}
}

// HasMessage checks if a message whose content is the given value exists in the store
func (s *Store) HasMessage(randomValue string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, msg := range s.messages {
		if msg.Content == randomValue {
			return true
		}
	}
	return false
}
