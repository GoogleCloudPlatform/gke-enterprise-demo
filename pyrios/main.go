/*
Copyright 2018 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

/*
Pyrios is an Elasticsearch proxy.
Pyrios forwards the HTTP request from a client to the on prem ElasticSearch cluster
and sends the response back to the client.
The in-cluster application can access the pyrios API endpoint via the `pyrios` service.
*/
package main

import (
	"cloud.google.com/go/compute/metadata"
	"context"
	"contrib.go.opencensus.io/exporter/stackdriver"
	"fmt"
	"go.opencensus.io/trace"
	"io"
	"log"
	"net/http"
	"os"
)

// Sets the default server IP and port for ElasticSearch server
const (
	defaultESServer = "127.0.0.1"
	defaultESPort   = 9200
)

/*
HandleHTTP is our main HTTP handler.
It takes the IP address of the on prem elasticsearch endpoint
in our demo. This is the regional static IP address exposed by the internal
load balancer of the on premise cluster's elastic-client service.
It takes a request from a client, forwards over to the on prem  elasticsearch
endpoint, then copy the response back.
*/
func handleHTTP(esServer string, w http.ResponseWriter, r *http.Request) {
	ep := *r.URL
	path := ep.Path
	ep.Host = fmt.Sprintf("%s:%d", esServer, defaultESPort)
	ep.Scheme = "http"

	startOptions := trace.WithSampler(trace.AlwaysSample())
	_, span := trace.StartSpan(r.Context(), path, startOptions)
	defer span.End()

	// Rewrite the request with the elasticsearch endpoint.
	req, err := http.NewRequest(r.Method, ep.String(), r.Body)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		log.Printf("error creating new request encountered: %v ", err)
		return
	}
	// Enforce the Content-Type for working with ES 6.x and up.
	// https://www.elastic.co/blog/strict-content-type-checking-for-elasticsearch-rest-requests
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		log.Printf("error sending request to the on prem elasticsearch cluster encountered: %v ", err)
		return
	}

	// Copy the response head and body from the elasticsearch API 's response
	// and send back to the client side.
	w.WriteHeader(http.StatusOK)
	copyHeader(w.Header(), resp.Header)
	io.Copy(w, resp.Body)
	defer resp.Body.Close()
	log.Print("Pyrios proxy request handled successfully")
}

// Helper func copies http headers from src to dst.
// It returns nothing, dst is changed and returned as a copy of src.
func copyHeader(dst, src http.Header) {
	for k, vv := range src {
		for _, v := range vv {
			dst.Add(k, v)
		}
	}
}

// Our main entry function to read relevant environment variables
// and set up the http handler.
func main() {
	gcpProject := os.Getenv("GCP_PROJECT")
	var err error
	if gcpProject == "" {
		metadataClient := metadata.NewClient(http.DefaultClient)
		if metadataClient == nil {
			log.Fatal("Metadata client failed to create")
		}
		gcpProject, err = metadataClient.ProjectID()
		if err != nil {
			log.Fatal("Cannot determine GCP project")
		}
	}

	// Here we decide where to export our OpenCensus data.
	exporter, err := stackdriver.NewExporter(
		stackdriver.Options{
			ProjectID: gcpProject,
		})
	if err != nil {
		log.Fatal("Failed to create Stackdriver trace exporter")
	}
	trace.RegisterExporter(exporter)

	// Here we read ES_SERVER from the environment or use a default value.
	esServer := os.Getenv("ES_SERVER")
	if esServer == "" {
		log.Print(fmt.Sprintf("ES_SERVER is not set, using default value of %s", defaultESServer))
		esServer = defaultESServer
	}

	// Set up the HTTP server with a http handler.
	// https://godoc.org/net/http Custom Server.
	s := &http.Server{
		Addr: fmt.Sprintf(":%d", defaultESPort),
		Handler: http.HandlerFunc(
			func(w http.ResponseWriter, r *http.Request) {
				handleHTTP(esServer, w, r)
			})}

	defer s.Shutdown(context.Background())
	log.Print("Starting pyrios proxy")
	s.ListenAndServe()
}
