package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"google.golang.org/genproto/googleapis/api/annotations"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/descriptorpb"
)

// APIDefinition represents a single API endpoint
type APIDefinition struct {
	Name     string `json:"name"`     // RPC method name
	API      string `json:"api"`      // HTTP path
	Method   string `json:"method"`   // HTTP method
	Request  string `json:"request"`  // Request type name
	Response string `json:"response"` // Response type name
}

// downloadFile downloads a file from URL to the specified path
func downloadFile(url, destPath string) error {
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("bad status: %s", resp.Status)
	}

	out, err := os.Create(destPath)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	return err
}

// ensureGoogleAPIs downloads required Google API proto files if they don't exist
func ensureGoogleAPIs() error {
	apiDir := "../proto/google/api"
	if err := os.MkdirAll(apiDir, 0755); err != nil {
		return fmt.Errorf("failed to create google/api directory: %v", err)
	}

	files := map[string]string{
		"annotations.proto": "https://raw.githubusercontent.com/googleapis/googleapis/master/google/api/annotations.proto",
		"http.proto":        "https://raw.githubusercontent.com/googleapis/googleapis/master/google/api/http.proto",
	}

	for file, url := range files {
		destPath := filepath.Join(apiDir, file)
		if _, err := os.Stat(destPath); os.IsNotExist(err) {
			fmt.Printf("Downloading %s...\n", file)
			if err := downloadFile(url, destPath); err != nil {
				return fmt.Errorf("failed to download %s: %v", file, err)
			}
		}
	}
	return nil
}

func parseProtoFile(filePath string, verbose bool) ([]APIDefinition, error) {
	// Run protoc to get file descriptor set
	tmpFile := filepath.Join(os.TempDir(), "descriptor.pb")
	defer os.Remove(tmpFile)

	protoDir := filepath.Dir(filePath)
	cmd := exec.Command("protoc",
		"--include_imports",
		"--include_source_info",
		fmt.Sprintf("--proto_path=%s", protoDir),
		fmt.Sprintf("--proto_path=%s", filepath.Dir(protoDir)), // for google/api imports
		"--descriptor_set_out="+tmpFile,
		filePath,
	)
	// log the command
	if verbose {
		fmt.Fprintf(os.Stderr, "%s\n", cmd.String())
	}
	if out, err := cmd.CombinedOutput(); err != nil {
		if errors.Is(err, exec.ErrNotFound) {
			// print the error
			fmt.Fprintf(os.Stderr, "protoc not found: %v\n", err)
			// prompt installing protoc
			fmt.Fprintf(os.Stderr, "Please install protoc: https://grpc.io/docs/languages/go/quickstart/#install-the-protoc-compiler\n > MacOS: brew install protobuf\n > Ubuntu: sudo apt-get install protobuf-compiler\n")
			os.Exit(1)
		}
		return nil, fmt.Errorf("protoc failed: %v\n%s", err, out)
	}

	// Read the descriptor set
	descBytes, err := os.ReadFile(tmpFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read descriptor set: %v", err)
	}

	// Parse the descriptor set
	fdSet := &descriptorpb.FileDescriptorSet{}
	if err := proto.Unmarshal(descBytes, fdSet); err != nil {
		return nil, fmt.Errorf("failed to parse descriptor set: %v", err)
	}

	var apis []APIDefinition

	// Process each file
	for _, fd := range fdSet.GetFile() {
		// Process each service
		for _, svc := range fd.GetService() {
			// Process each method
			for _, method := range svc.GetMethod() {
				api := APIDefinition{
					Name:     *method.Name,
					Request:  filepath.Base(*method.InputType),
					Response: filepath.Base(*method.OutputType),
				}

				// Extract HTTP method and path from options
				if method.Options != nil {
					if proto.HasExtension(method.Options, annotations.E_Http) {
						httpRule := proto.GetExtension(method.Options, annotations.E_Http).(*annotations.HttpRule)
						if httpRule != nil {
							switch {
							case httpRule.GetGet() != "":
								api.Method = "GET"
								api.API = httpRule.GetGet()
							case httpRule.GetPost() != "":
								api.Method = "POST"
								api.API = httpRule.GetPost()
							case httpRule.GetPut() != "":
								api.Method = "PUT"
								api.API = httpRule.GetPut()
							case httpRule.GetDelete() != "":
								api.Method = "DELETE"
								api.API = httpRule.GetDelete()
							case httpRule.GetPatch() != "":
								api.Method = "PATCH"
								api.API = httpRule.GetPatch()
							}
						}
					}
				}

				apis = append(apis, api)
			}
		}
	}

	return apis, nil
}

func processFiles(verbose bool) ([]APIDefinition, error) {
	// Ensure Google API proto files are available
	if err := ensureGoogleAPIs(); err != nil {
		fmt.Fprintf(os.Stderr, "Failed to ensure Google APIs: %v\n", err)
		os.Exit(1)
	}

	// Find all proto files in the proto directory
	protoFiles, err := filepath.Glob("../proto/*.proto")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to find proto files: %v\n", err)
		os.Exit(1)
	}

	allAPIs := make([]APIDefinition, 0)

	// Parse each proto file
	for _, file := range protoFiles {
		apis, err := parseProtoFile(file, verbose)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Failed to parse %s: %v\n", file, err)
			continue
		}
		allAPIs = append(allAPIs, apis...)
	}

	return allAPIs, nil
}

const help = `
gen help to parse proto files and output the API definitions in JSON format.

Usage: gen <cmd> [OPTIONS]

Available commands:
  parse                       parse proto files and output the API definitions in JSON format.
  help                        show help message

Options:
  --help   show help message
`

func main() {
	err := handle(os.Args[1:])
	if err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}

func handle(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("requires command")
	}
	cmd := args[0]

	_ = cmd
	args = args[1:]

	var flag string
	var remainArgs []string
	var verbose bool
	n := len(args)
	for i := 0; i < n; i++ {
		if args[i] == "--flag" {
			if i+1 >= n {
				return fmt.Errorf("%v requires arg", args[i])
			}
			flag = args[i+1]
			i++
			continue
		}
		if args[i] == "--help" {
			fmt.Println(strings.TrimSpace(help))
			return nil
		}
		if args[i] == "--verbose" {
			verbose = true
			continue
		}
		if args[i] == "--" {
			remainArgs = append(remainArgs, args[i+1:]...)
			break
		}
		if strings.HasPrefix(args[i], "-") {
			return fmt.Errorf("unrecognized flag: %v", args[i])
		}
		remainArgs = append(remainArgs, args[i])
	}
	// TODO handle
	_ = flag

	allAPIs, err := processFiles(verbose)
	if err != nil {
		return err
	}

	if cmd == "parse" {
		// Output as JSON
		encoder := json.NewEncoder(os.Stdout)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(allAPIs); err != nil {
			return fmt.Errorf("failed to encode APIs: %v", err)
		}
		return nil
	}
	if cmd == "gen" {
		var writer io.Writer
		if len(remainArgs) == 0 {
			// to stdout
			writer = os.Stdout
		} else {
			file := remainArgs[0]
			// Create and open output file
			f, err := os.Create(file)
			if err != nil {
				return fmt.Errorf("failed to create file %s: %v", file, err)
			}
			defer f.Close()
			writer = f
		}

		if err := genSwift(allAPIs, writer); err != nil {
			return fmt.Errorf("failed to generate Swift code: %v", err)
		}
		return nil
	}

	return nil
}
