//! A throwaway store root and a scripted loopback HTTP server — the only
//! network these tests touch. The server logs every request so Range
//! behavior is asserted, not inferred.

use std::collections::HashMap;
use std::io::{BufRead, BufReader, Write};
use std::net::{SocketAddr, TcpListener, TcpStream};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::{Arc, Mutex};
use std::{env, fs, process, thread};

pub struct TempRoot(pub PathBuf);

impl TempRoot {
    pub fn new() -> Self {
        static COUNTER: AtomicU32 = AtomicU32::new(0);
        let n = COUNTER.fetch_add(1, Ordering::Relaxed);
        let path = env::temp_dir().join(format!("calamo-store-test-{}-{n}", process::id()));
        fs::create_dir_all(&path).expect("temp root");
        Self(path)
    }

    pub fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for TempRoot {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

pub enum Route {
    RangeAware(Vec<u8>),
    IgnoresRange(Vec<u8>),
    RedirectAbsolute(String),
    RedirectRelative(String),
    Status(u16),
}

pub struct Server {
    addr: SocketAddr,
    requests: Arc<Mutex<Vec<String>>>,
}

impl Server {
    pub fn start(routes: HashMap<String, Route>) -> Self {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind loopback");
        let addr = listener.local_addr().expect("local addr");
        let requests = Arc::new(Mutex::new(Vec::new()));
        let log = Arc::clone(&requests);
        let routes = Arc::new(routes);
        thread::spawn(move || {
            for stream in listener.incoming().flatten() {
                handle(stream, addr, &routes, &log);
            }
        });
        Self { addr, requests }
    }

    pub fn endpoint(&self) -> String {
        format!("http://{}", self.addr)
    }

    pub fn requests(&self) -> Vec<String> {
        self.requests.lock().expect("requests lock").clone()
    }
}

fn handle(
    stream: TcpStream,
    addr: SocketAddr,
    routes: &HashMap<String, Route>,
    log: &Mutex<Vec<String>>,
) {
    let Some((path, range)) = read_request(&stream) else {
        return;
    };
    let range_note = range
        .as_deref()
        .map(|r| format!(" range={r}"))
        .unwrap_or_default();
    log.lock()
        .expect("log lock")
        .push(format!("GET {path}{range_note}"));
    let mut stream = stream;
    match routes.get(&path) {
        None => respond(&mut stream, 404, &[], b""),
        Some(Route::Status(status)) => respond(&mut stream, *status, &[], b""),
        Some(Route::IgnoresRange(body)) => respond(&mut stream, 200, &[], body),
        Some(Route::RangeAware(body)) => serve_range(&mut stream, body, range.as_deref()),
        Some(Route::RedirectAbsolute(target)) => {
            let location = format!("Location: http://{addr}{target}");
            respond(&mut stream, 302, &[&location], b"");
        }
        Some(Route::RedirectRelative(target)) => {
            let location = format!("Location: {target}");
            respond(&mut stream, 302, &[&location], b"");
        }
    }
}

fn read_request(stream: &TcpStream) -> Option<(String, Option<String>)> {
    let mut reader = BufReader::new(stream);
    let mut request_line = String::new();
    reader.read_line(&mut request_line).ok()?;
    let path = request_line.split_whitespace().nth(1)?.to_string();
    let mut range = None;
    loop {
        let mut line = String::new();
        reader.read_line(&mut line).ok()?;
        let line = line.trim_end();
        if line.is_empty() {
            return Some((path, range));
        }
        if let Some(value) = line.to_ascii_lowercase().strip_prefix("range: ") {
            range = Some(value.to_string());
        }
    }
}

fn serve_range(stream: &mut TcpStream, body: &[u8], range: Option<&str>) {
    let Some((from, to)) = parse_range(range) else {
        return respond(stream, 200, &[], body);
    };
    if from >= body.len() {
        return respond(stream, 416, &[], b"");
    }
    let end = to.min(body.len());
    let content_range = format!("Content-Range: bytes {from}-{}/{}", end - 1, body.len());
    respond(stream, 206, &[&content_range], &body[from..end]);
}

/// `bytes=from-to` (inclusive) or `bytes=from-` → half-open `(from, to)`.
fn parse_range(range: Option<&str>) -> Option<(usize, usize)> {
    let (from, to) = range?.strip_prefix("bytes=")?.split_once('-')?;
    let from = from.parse().ok()?;
    let to = if to.is_empty() {
        usize::MAX
    } else {
        to.parse::<usize>().ok()?.checked_add(1)?
    };
    Some((from, to))
}

fn respond(stream: &mut TcpStream, status: u16, extra_headers: &[&str], body: &[u8]) {
    let mut head = format!("HTTP/1.1 {status} X\r\nContent-Length: {}\r\n", body.len());
    for header in extra_headers {
        head.push_str(header);
        head.push_str("\r\n");
    }
    head.push_str("Connection: close\r\n\r\n");
    let _ = stream.write_all(head.as_bytes());
    let _ = stream.write_all(body);
}
