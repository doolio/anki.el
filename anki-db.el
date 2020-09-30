;;; anki-db.el -*- lexical-binding: t; -*-

;; Author: Damon Chan <elecming@gmail.com>

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(defun anki-db-current-deck-total-review-card-number ()
  (let ((result (caar (anki-core-sql `[:select (funcall count :distinct id ) :from revlog :where (= did ,anki-core-current-deck-id)]))))
    (if result result 0)))

(defun anki-db-current-deck-total-card-number ()
  (length anki-search-entries))


(defun anki-db-current-deck-total-due-card-number ()
  (seq-count (lambda (x) (equal x t))
             (cl-mapcar (lambda (x)
                          (time-less-p (encode-time (parse-time-string (nth 3 x))) (current-time)))
                        (anki-core-sql `[:select *
                                         :from [:select *
                                                :from [:select :distinct [id did due_days due_date] :from revlog :where (= did ,anki-core-current-deck-id) :order-by ROWID :asc]
                                                :group-by id]]))))

(defun anki-db-current-deck-total-again-number ()
  (seq-count (lambda (x) (equal x t))
             (cl-mapcar (lambda (x)
                          (and (< (nth 2 x) 1); due_days is less than 1 day
                               (< (/ (- (time-convert (current-time) 'integer)
                                        (time-convert (encode-time (parse-time-string (nth 3 x))) 'integer)) (* 24 3600.0)) 1))) ; real due_days is less than 1 day
                        (anki-core-sql `[:select *
                                         :from [:select *
                                                :from [:select :distinct [id did due_days due_date] :from revlog :where (= did ,anki-core-current-deck-id) :order-by ROWID :asc]
                                                :group-by id]]))))

(defun anki-db-latest-due-card-or-random-card ()
  "Get latest due card or a random card if no review logs."
  (let* ((result (car (anki-core-sql `[:select [id did due_days (funcall min due_date)]
                                       :from [:select *
                                              :from [:select :distinct [id did due_days due_date] :from revlog :where (= did ,anki-core-current-deck-id) :order-by ROWID :asc]
                                              :group-by id]])))
         (id (nth 0 result))
         ;; (due-days (nth 1 result))
         (due-date (if id (encode-time (parse-time-string (nth 3 result))))))
    (if (and id (time-less-p due-date (current-time))) ; the lastest card due-date is less than current date
        (gethash id anki-core-hash-table)
      (nth (random (1- (length anki-search-entries))) anki-search-entries))))

(provide 'anki-db)
