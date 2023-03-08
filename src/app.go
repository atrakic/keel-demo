package main

import (
	"fmt"
	"log"
	"net/http"
)

var version = "v0"

func main() {

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Add("server", "keel-demo")
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "OK\n")
	})

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Welcome to my website! Version %s", version)
	})

	fmt.Printf("App is starting, version: %s \n", version)
	log.Fatal(http.ListenAndServe(":8500", nil))
}
