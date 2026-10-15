package main

import (
	"log/slog"
	"os"
	"strings"

	"github.com/spectrocloud/palette-samples/cluster-scanner/internal"
	"github.com/spectrocloud/palette-sdk-go/client"
)

func main() {

	// Read environment variables required to initialize the Palette client.
	host := os.Getenv("PALETTE_HOST")
	apiKey := os.Getenv("PALETTE_API_KEY")
	projectUid := os.Getenv("PALETTE_PROJECT_UID")

	// Read the optional list of cloud types to scan. If it is not set, all cloud types are scanned.
	cloudTypes := internal.ParseCloudTypes(os.Getenv("SCAN_CLOUD_TYPES"))

	// Initialize a logger for structured output.
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))

	// Ensure the required environment variables are provided.
	if host == "" || apiKey == "" {
		logger.Error("You must specify the PALETTE_HOST and PALETTE_API_KEY environment variables.")
		os.Exit(1)
	}

	// Initialize a Palette client with the provided host and API key.
	paletteClient := client.New(
		client.WithPaletteURI(host),
		client.WithAPIKey(apiKey),
	)

	// Set the scope for the client based on wether the project UID is provided.
	if projectUid != "" {
		client.WithScopeProject(projectUid)(paletteClient)
		logger.Info("Setting scope to project.")
	} else {
		client.WithScopeTenant()(paletteClient)
		logger.Info("Setting scope to tenant.")
	}

	// Search for clusters using the Palette client and the SearchClusters function.
	logger.Info("Searching for clusters...")
	clusters, err := internal.SearchClusters(paletteClient)
	if err != nil {
		logger.Error("Failed to search cluster summaries", "error", err)
		os.Exit(2)
	}

	// Check if any clusters were found.
	if len(clusters) == 0 {
		logger.Warn("There are no clusters running.")
		return
	}

	// Keep only the clusters whose cloud type is listed in SCAN_CLOUD_TYPES, if it is set.
	if len(cloudTypes) != 0 {
		logger.Info("Filtering clusters by cloud type.", "cloudTypes", strings.Join(cloudTypes, ","))
		clusters = internal.FilterClustersByCloudType(clusters, cloudTypes)
		if len(clusters) == 0 {
			logger.Warn("There are no clusters running with the specified cloud types.")
			return
		}
	}

	// Check for clusters running for more than 24 hours using the SearchOldClusters function.
	messageArray, err := internal.SearchOldClusters(clusters)
	if err != nil {
		logger.Error("Failed to search for old clusters", "error", err)
		os.Exit(2)
	}
	if len(messageArray) != 0 {
		logger.Info("The following clusters have been running for over 24 hours. Please delete them if they're no longer needed:")
		for _, message := range messageArray {
			logger.Info(message)
		}
        return
	}
	logger.Info("There are no clusters running for more than 24 hours.")
}
