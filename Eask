;; -*- mode: eask; lexical-binding: t -*-

(package "chime"
         "0.7.0"
         "Modeline and desktop notifications for org-agenda")

(website-url "https://github.com/cjennings/chime")
(keywords "calendar" "convenience" "notification" "alert" "org-agenda")

(package-file "chime.el")
(files "chime.el"
       "chime-debug.el"
       "chime-org-contacts.el"
       "convert-org-contacts-birthdays.el"
       "sounds")

(source 'gnu)
(source 'nongnu)
(source 'melpa)

(depends-on "emacs" "27.1")
(depends-on "alert" "1.2")
(depends-on "async" "1.9.3")
(depends-on "dash" "2.18.0")

(development
 (depends-on "elisp-lint")
 (depends-on "package-lint")
 (depends-on "undercover"))
