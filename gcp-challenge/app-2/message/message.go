package message

import (
	"sync"
	"time"
)

// Message represents a single message with its metadata
type Message struct {
	RandomValue string
	ReceivedAt  time.Time
	Validated   bool
}

func New(randomValue string, validated bool) Message {
	return Message{
		RandomValue: randomValue,
		ReceivedAt:  time.Now(),
		Validated:   validated,
	}
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
func (s *Store) AddMessage(message Message) {
	s.mu.Lock()
	defer s.mu.Unlock()

	s.messages = append(s.messages, message)

	if len(s.messages) > s.maxSize {
		s.messages = s.messages[len(s.messages)-s.maxSize:]
	}
}

// HasMessage checks if a message whose content is the given value exists in the store
func (s *Store) HasMessage(randomValue string) bool {
	s.mu.RLock()
	defer s.mu.RUnlock()

	for _, msg := range s.messages {
		if msg.RandomValue == randomValue {
			return true
		}
	}
	return false
}

// GetMessages returns all messages from the store
func (s *Store) GetMessages() []Message {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.messages
}
