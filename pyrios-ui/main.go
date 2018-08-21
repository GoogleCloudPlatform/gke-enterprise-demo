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

package main

import (
	"context"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"cloud.google.com/go/compute/metadata"
	monitoring "cloud.google.com/go/monitoring/apiv3"
	googlepb "github.com/golang/protobuf/ptypes/timestamp"
	"github.com/tidwall/gjson"
	"contrib.go.opencensus.io/exporter/stackdriver"
	"go.opencensus.io/trace"
	metricpb "google.golang.org/genproto/googleapis/api/metric"
	monitoredrespb "google.golang.org/genproto/googleapis/api/monitoredres"
	monitoringpb "google.golang.org/genproto/googleapis/monitoring/v3"
)

// We need to define a struct that holds the data for the template rendering.
// Our template contains five values.
type ShakespeareResult struct {
	ESVersion           string
	ClusterStatus       string
	NumberOfShards      string
	NumberOfHits        string
	NumberOfLeonatoHits string
}

// This is our handler for the /shakespeare endpoint.
func Shakespeare(
	w http.ResponseWriter,
	req *http.Request,
	ctx context.Context,
	metricClient *monitoring.MetricClient,
	gcpProject string,
	pyrios string) {
	// Here we setup our tracer to use "AlwaysSample" so every request is traced.
	startOptions := trace.WithSampler(trace.AlwaysSample())
	_, span := trace.StartSpan(req.Context(), "pyrios-ui validation", startOptions)
	// Trace the entire length of Shakespeare().
	defer span.End()

	log.Print("Starting Shakespeare data validation")

	data := ShakespeareResult{}

	// Make a GET request through the pyrios proxy.
	resp, err := http.Get(fmt.Sprintf("http://%s:9200/", pyrios))
	json, err := ioutil.ReadAll(resp.Body)
	// Find the value we want and store it in our template struct.
	data.ESVersion = gjson.GetBytes(json, "version.number").String()

	resp, err = http.Get(fmt.Sprintf("http://%s:9200/_cluster/health", pyrios))
	json, err = ioutil.ReadAll(resp.Body)
	data.ClusterStatus = gjson.GetBytes(json, "status").String()

	resp, err = http.Get(fmt.Sprintf("http://%s:9200/shakespeare", pyrios))
	json, err = ioutil.ReadAll(resp.Body)
	data.NumberOfShards = gjson.GetBytes(json, "shakespeare.settings.index.number_of_shards").String()

	numberOfHitsQuery := `
	{
	  "query": { "match_all": {} },
	  "from": 10,
	  "size": 5
	}`

	const jsonType = "application/json"

	resp, err = http.Post(fmt.Sprintf("http://%s:9200/_search", pyrios), jsonType, strings.NewReader(numberOfHitsQuery))
	json, err = ioutil.ReadAll(resp.Body)
	data.NumberOfHits = gjson.GetBytes(json, "hits.hits.#").String()

	numberOfLeonatoHitsQuery := `
	{
	    "query": {
	    "match" : {
	        "speaker" : "LEONATO"
	        }
	    }
	}
	`

	resp, err = http.Post(fmt.Sprintf("http://%s:9200/_search", pyrios), jsonType, strings.NewReader(numberOfLeonatoHitsQuery))
	json, err = ioutil.ReadAll(resp.Body)
	data.NumberOfLeonatoHits = gjson.GetBytes(json, "hits.hits.#").String()

	// The values were stored as strings for the template library.
	// We need to convert it to Int64 for the custom metric.
	leonatoInt, err := strconv.ParseInt(data.NumberOfLeonatoHits, 10, 64)
	if err != nil {
		leonatoInt = 0
	}

	// Here we define the data for our custom metric.
	// There metric takes place Now().
	// It's value is an Int64 version of data.NumberOfLeonatoHits.
	dataPoint := &monitoringpb.Point{
		Interval: &monitoringpb.TimeInterval{
			EndTime: &googlepb.Timestamp{
				Seconds: time.Now().Unix(),
			},
		},
		Value: &monitoringpb.TypedValue{
			Value: &monitoringpb.TypedValue_Int64Value{
				Int64Value: leonatoInt,
			},
		},
	}

	// Here we define a TimeSeries that contains the type of our custom metric.
	// It also contains the Point that we defined above.
	timeSeriesRequest := &monitoringpb.CreateTimeSeriesRequest{
		Name: fmt.Sprintf("projects/%s", gcpProject),
		TimeSeries: []*monitoringpb.TimeSeries{
			{
				Metric: &metricpb.Metric{
					Type:   "custom.googleapis.com/pyrios-ui/numberOfLeonatoHits",
					Labels: nil,
				},
				Resource: &monitoredrespb.MonitoredResource{
					Type:   "global",
					Labels: nil,
				},
				Points: []*monitoringpb.Point{
					dataPoint,
				},
			},
		},
	}

	// Here we publish the TimeSeries.
	err = metricClient.CreateTimeSeries(ctx, timeSeriesRequest)
	if err != nil {
		log.Printf("Failed to create time series: %s", err)
	}

	// Create the template struct from a file.
	tmpl := template.Must(template.ParseFiles("./static/index.html"))
	// Render the template HTML.
	err = tmpl.Execute(w, data)
	if err != nil {
		log.Printf("Failed to execute template:  %s", err)
	}
	log.Print("Shakespeare data validation completed")
}

func main() {
	// Build a default context since main() does not have a Request struct to use.
	ctx := context.Background()

	// Query the GCE metadata server to find the current project ID.
	gcpProject := os.Getenv("GCP_PROJECT")
	var err error
	if gcpProject == "" {
		metadataClient := metadata.NewClient(http.DefaultClient)
		if metadataClient == nil {
			log.Fatal("Can't create metadata Client")
		}
		gcpProject, err = metadataClient.ProjectID()
		if err != nil {
			log.Fatal("Cannot determine GCP project")
		}
	}

	// Decide where to export our OpenCensus data.
	exporter, err := stackdriver.NewExporter(
		stackdriver.Options{
			ProjectID: gcpProject,
		})
	if err != nil {
		log.Fatal("Failed to create Stackdriver trace exporter")
	}
	trace.RegisterExporter(exporter)

	// Make sure we know how to find the pyrios proxy and exit out if we dont.
	pyrios := os.Getenv("PYRIOS_ENDPOINT")
	if pyrios == "" {
		log.Fatal("PYRIOS_ENDPOINT environment variable not set")
	}

	// Setup our Stackdriver metrics client.
	metricClient, err := monitoring.NewMetricClient(ctx)
	if err != nil {
		log.Fatal("Failed to create Stackdriver metrics client")
	}

	// Define which function handles requests for the / endpoint.
	http.HandleFunc("/", func(w http.ResponseWriter, req *http.Request) {
		Shakespeare(w, req, ctx, metricClient, gcpProject, pyrios)
	})
	log.Print("Starting pyrios-ui")
	http.ListenAndServe(":8080", nil)

}
