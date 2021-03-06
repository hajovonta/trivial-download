(in-package :cl-user)
(defpackage trivial-download
  (:use :cl)
  (:export :file-size
           :with-download
           :with-download-progress
           :download
           :it))
(in-package :trivial-download)

(defmacro awhile (expr &body body)
  `(do ((it ,expr ,expr))
       ((not it))
     ,@body))

(defun file-size (url)
  "Take a URL to a file, return the size (in bytes)."
  (handler-case
      (parse-integer
       (cdr
        (assoc :content-length
               (third (multiple-value-list
                       (drakma:http-request url :want-stream t :method :head))))))
    (t () nil)))

(defparameter +size-symbol-map+
  (list (cons 1000000000000 "TB")
        (cons 1000000000 "GB")
        (cons 1000000 "MB")
        (cons 1000 "kB")
        (cons 1 "B")))

(defun human-file-size (size)
  "Take a file size (in bytes), return it as a human-readable string."
  (let ((pair (loop for pair in +size-symbol-map+
                    if (>= size (car pair)) return pair)))
    (format nil "~f ~A" (/ size (car pair)) (cdr pair))))

(defun percentage (total-bytes current-bytes)
  (floor (/ (* current-bytes 100) total-bytes)))

(defmacro with-download (url &rest body)
  `(let* ((file-size (file-size ,url))
          (stream (drakma:http-request ,url
                                       :want-stream t)))
     (format t "Downloading ~S (~A)~&" ,url (if file-size
                                                (human-file-size file-size)
                                                "Unknown size"))
     (finish-output nil)
     (awhile (read-byte stream nil nil)
             ,@body)
     (close stream)))

(defmacro with-download-progress (url &rest body)
  `(let ((byte-count 0)
         (last-percentage 0))
     (with-download ,url
       (progn
         (incf byte-count)
         (if file-size
             (let ((progress (percentage file-size byte-count)))
               (if (> progress last-percentage)
                   (progn
                    (if (eql 0 (mod progress 10))
                         (format t "~D%" progress)
                         (format t "."))
                    (finish-output nil)))
               (setf last-percentage progress)))
         ,@body))))

(defun download (url output)
  "Download a file and save it to a pathname."
  (with-open-file (file output
                        :direction :output
                        :if-does-not-exist :create
                        :if-exists :supersede
                        :element-type '(unsigned-byte 8))
    (with-download-progress url
      (write-byte it file))))
