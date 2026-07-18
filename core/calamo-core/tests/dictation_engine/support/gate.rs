//! Lets a test hold a port double in mid-call.

use std::sync::{Arc, Condvar, Mutex};

use super::WAIT;

pub struct Gate {
    open: Mutex<bool>,
    opened: Condvar,
}

impl Gate {
    pub fn closed() -> Arc<Self> {
        Arc::new(Self {
            open: Mutex::new(false),
            opened: Condvar::new(),
        })
    }

    pub fn open(&self) {
        *self.open.lock().unwrap() = true;
        self.opened.notify_all();
    }

    /// Self-releases after WAIT so a forgotten gate never wedges the tests.
    pub(super) fn pass(&self) {
        let mut open = self.open.lock().unwrap();
        while !*open {
            let (guard, timeout) = self.opened.wait_timeout(open, WAIT).unwrap();
            open = guard;
            if timeout.timed_out() {
                return;
            }
        }
    }
}
