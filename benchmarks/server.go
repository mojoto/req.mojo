// HTTP/1.1 loopback fixture. Bodies are allocated before timing begins.
package main

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strconv"
)

func main() {
	headerCount := 0
	if value := os.Getenv("BENCH_HEADERS"); value != "" {
		var err error
		headerCount, err = strconv.Atoi(value)
		if err != nil || headerCount < 0 || headerCount > 128 {
			panic("BENCH_HEADERS must be between 0 and 128")
		}
	}
	headers := make([][2]string, headerCount)
	for i := range headers {
		headers[i] = [2]string{"X-Bench-Header-Name-" + strconv.Itoa(i), strconv.Itoa(i)}
	}
	uploadSize := 0
	if value := os.Getenv("BENCH_UPLOAD_SIZE"); value != "" {
		var err error
		uploadSize, err = strconv.Atoi(value)
		if err != nil || uploadSize < 0 || uploadSize > 1048576 {
			panic("Invalid BENCH_UPLOAD_SIZE")
		}
	}
	expectedUpload := bytes.Repeat([]byte{'x'}, uploadSize)
	bodies := make(map[string][]byte)
	for _, size := range []int{128, 4096, 65536, 1048576} {
		bodies["/keep/"+strconv.Itoa(size)] = bytes.Repeat([]byte{'x'}, size)
	}
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	fmt.Println(listener.Addr())
	server := http.Server{Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, ok := bodies[r.URL.Path]
		if !ok {
			http.NotFound(w, r)
			return
		}
		if uploadSize > 0 {
			if r.Method != "POST" || r.ContentLength != int64(uploadSize) {
				http.Error(w, "Invalid upload method or length", http.StatusBadRequest)
				return
			}
			upload, err := io.ReadAll(io.LimitReader(r.Body, int64(uploadSize)+1))
			if err != nil || !bytes.Equal(upload, expectedUpload) {
				http.Error(w, "Invalid upload body", http.StatusBadRequest)
				return
			}
		}
		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Content-Length", strconv.Itoa(len(body)))
		w.Header().Set("X-Connection-Id", r.RemoteAddr)
		for _, header := range headers {
			w.Header().Set(header[0], header[1])
		}
		if _, err := w.Write(body); err != nil {
			return // A client may close the socket at the end of a trial.
		}
	})}
	if err := server.Serve(listener); err != nil {
		panic(err)
	}
}
