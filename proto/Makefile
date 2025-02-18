# Protoc binary
PROTOC := protoc

# Directories
GO_OUT_DIR := ../server/proto
TS_OUT_DIR := ../frontend/src/proto
SWIFT_OUT_DIR := ../task-spanner/Generated
OPENAPI_OUT_DIR := ../server/api/openapi

# Proto files
PROTO_FILES := $(wildcard *.proto)

.PHONY: all
all: deps gen

.PHONY: deps
deps:
	go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
	go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
	go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@latest
	go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2@latest

.PHONY: gen
gen:
	go run ../tools/gen/main.go

.PHONY: ts
ts:
	@mkdir -p $(TS_OUT_DIR)
	$(PROTOC) \
		-I . \
		-I$(shell buf build -o - | tar -tf - | grep -o '^.*googleapis' | head -n1) \
		-I$(shell buf build -o - | tar -tf - | grep -o '^.*grpc-gateway' | head -n1) \
		--plugin=protoc-gen-ts=../frontend/node_modules/.bin/protoc-gen-ts \
		--ts_out=$(TS_OUT_DIR) \
		$(PROTO_FILES)

.PHONY: swift
swift:
	@mkdir -p $(SWIFT_OUT_DIR)
	$(PROTOC) \
		-I . \
		-I$(shell buf build -o - | tar -tf - | grep -o '^.*googleapis' | head -n1) \
		-I$(shell buf build -o - | tar -tf - | grep -o '^.*grpc-gateway' | head -n1) \
		--swift_opt=Visibility=Public \
		--swift_opt=ModuleName=TaskSpannerV1 \
		--swift_out=$(SWIFT_OUT_DIR) \
		--grpc-swift_opt=Visibility=Public \
		--grpc-swift_opt=ModuleName=TaskSpannerV1 \
		--grpc-swift_out=$(SWIFT_OUT_DIR) \
		$(PROTO_FILES)

.PHONY: openapi
openapi:
	@mkdir -p $(OPENAPI_OUT_DIR)
	$(PROTOC) \
		-I . \
		-I$(shell buf build -o - | tar -tf - | grep -o '^.*googleapis' | head -n1) \
		-I$(shell buf build -o - | tar -tf - | grep -o '^.*grpc-gateway' | head -n1) \
		--openapiv2_out=$(OPENAPI_OUT_DIR) \
		--openapiv2_opt=logtostderr=true \
		$(PROTO_FILES)

.PHONY: clean
clean:
	rm -rf $(GO_OUT_DIR)/* $(TS_OUT_DIR)/* $(SWIFT_OUT_DIR)/* $(OPENAPI_OUT_DIR)/*
	rm -rf google/api/*.proto 