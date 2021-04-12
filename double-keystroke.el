;;; double-keystroke.el --- bind the command to a double-keystroke.

;; Author: Eugene Markov <upirtf@gmail.com>
;; URL: https://github.com/rtfupi/double-keystroke
;; Version: 0.1
;; Keywords:

;; Package-Requires: ((emacs "24.3") (edmacro "2.01"))

;; Copyright (C) 2021 Eugene Markov <...@gmail.com>

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
;; 02110-1301, USA.

;;; Commentary:
;;
;; Позволяет назначить команду на двойное нажатие клавиши клавиатуры.
;; Второе нажатие на клавишу должно происходить внутри заданного
;; интервала времени. Работает только для последнего события в key
;; sequence (не для prefix key). Прежнее назначение команды для  
;; для одиночного нажатия клавиши сохраняется.
;;
;; Пример 1:
;;
;; (defun HELP () (interactive) (message "HELP"))
;;
;; (defun SuperHELP () (interactive) (message "SuperHELP"))
;;
;;
;; (define-key foo-keymap (kbd "<f2>") 'HELP)
;; (double-keystroke-define-key foo-keymap (kbd "<f2>") 'SuperHELP)
;;
;; При одиночном нажатии клавиши F1, будет выведено сообщение "HELP".
;; При двойном нажатии клавиши F1 (c интервалом меньшим 300 мс по
;; умолчанию), будет выведено сообщение "SuperHELP".
;;
;;
;; Пример 2:
;;
;; (defun get-previous-active-buffer (l)
;;   "Get the previous active buffer other than ibuffer or minibuffer."
;;   (when l
;;     (if (string-match "^ " (or (buffer-name (car l)) " "))
;;         (get-previous-active-buffer (cdr l))
;;       (if (local-variable-p 'ibuffer-sorting-mode (car l))
;;           (get-previous-active-buffer (cdr l))
;;         (car l)))))
;;
;;
;; (defun switch-to-previous-buffer ()
;;   "Switch to the previous active buffer.."
;;   (interactive)
;;   (let ((b (get-previous-active-buffer (cdr (buffer-list)))))
;;     (when b (switch-to-buffer b))))
;;
;;
;; (global-set-key (kbd "C-x C-b") #'ibuffer)
;; (double-keystroke-define-key global-map (kbd "C-x C-b")
;;                              #'switch-to-previous-buffer)
;;
;; При одиночном вводе последовательности "C-x C-b", будет переключение
;; в Ibuffer. При вводе последовательности "C-x C-b", а потом вводе "C-b"
;; (в пределах интервала 300 мс. по умолчанию), будет переключение в
;; предыдущий активный буфер.
;;
;; FIXME: сделать проброс double-keystroke в global-map в случае зтенения
;;        одинарным кликом в текущей keymap через отдельную ф-ию.

;;; Code:

(require 'cl)
(require 'edmacro)



(defvar double-keystroke-interval 0.3)



;;;###autoload
(defun double-keystroke-define-key (keymap key def2 &optional fn-double interval doc)
  ;; Задать ф-ию для двойного нажатия клавиши.
  ;;
  ;; Можно использовать  `describe-key' (C-h k), чтобы получить нужную строку
  ;; для key.
  ;;
  ;; Работает только для последнего события в key sequence (не для prefix key)
  ;; (например 'Ctrl-x .' потом второй раз '.')
  ;;
  ;; Это будет работать, как для полных последовательностей ("C-x C-."), так
  ;; и для префиксных keymap.
  ;;
  ;; Пример для полной последовательности:
  ;;  (global-set-key (kbd "C-x C-.") #'evm-test-HELP)
  ;;  (double-keystroke-define-key global-map (kbd "C-x C-.") #'evm-test-COOL-HELP)
  ;;
  ;; Пример для префиксной keymap:
  ;;  (define-key ctl-x-map (kbd "C-.") #'evm-test-HELP)
  ;;  (double-keystroke-define-key ctl-x-map (kbd "C-.") #'evm-test-COOL-HELP)
  ;;
  ;; Для версии 24.3 (по крайней мере) есть одна засада: если определить
  ;; key binding для "C-x C-.", например, а затем удалить его через
  ;; (global-set-key (kbd "C-x C-.") nil) (а это можно сделать только так),
  ;; то повторное задание способом через префиксную keymap
  ;; (define-key ctl-x-map (kbd "C-.") ...) не сработает, т.к. в global-map
  ;; останется огрызок вида (67108910), который перекроет доступ к префиксной
  ;; keymap. Поэтому нельзя мешать эти два способа;
  ;;
  ;; Для пользовательской моды, например foo-mode, если нужно сделать
  ;; 'Ctrl-c Ctrl d' -> foo1, а для 'Ctrl-c Ctrl d', потом второй раз 'Ctrl d' -> foo2
  ;; то нужно выполнить 
  ;;   (defvar foo-mode-ctl-c-map (make-sparse-keymap)
  ;;          "Keymap for Ctrl-c prefix.")
  ;;   (defalias 'foo-mode-ctl-c-prefix foo-mode-ctl-c-map)
  ;;   (define-key foo-mode-map (kbd "\C-c") 'foo-mode-ctl-c-prefix)
  ;;   (define-key foo-mode-ctl-c-prefix (kbd "\C-d") 'foo1)
  ;;   (double-keystroke-define-key foo-mode-ctl-c-prefix (kbd "\C-d") 'foo2)

  ;; Для Alt нужно использовать (kbd "M-символ")
  ""

  (double-keystroke-unset-key keymap key)

  (when def2
    (setq key (double-keystroke-get-key-symbol key))
    (define-key
      keymap
      key
      (double-keystroke-make-fn keymap key def2 nil fn-double interval doc))
      ))



;;;###autoload
(defun double-keystroke-make-fn (keymap key def2 &optional def1 fn-double interval doc)
  ;; Сконструируем ф-ю.
  ""
  (setq key (double-keystroke-get-key-symbol key))

  (unless def1 (setq def1 (lookup-key keymap key)))

  (let ( (A "") (B "") (D ""))

    (when (and fn-double (not (intern-soft (symbol-name fn-double))))
      (intern (symbol-name fn-double)))

    (unless fn-double
      (setq fn-double (intern
                       (make-temp-name (concat "double-keystroke-fn-")))))

    (unless interval
      (setq interval double-keystroke-interval))

    (put fn-double 'double-keystroke-fn-double def2)
    (put fn-double 'double-keystroke-fn-single def1)
    (put fn-double 'double-keystroke-interval interval)
    (put fn-double 'double-keystroke-doc doc)

    (if def1
        ;; 
        (setq A `(call-interactively (quote ,def1)))
      (unless (eq keymap global-map)
        (setq B `(let ((fn (key-binding ,key)))
                   (if fn
                       (call-interactively fn))))))

    (when doc (setq D doc))

    (eval `(defun ,fn-double ()
             ,D
             (interactive)
             (let ((ev1 (this-command-keys-vector))); получили событие, которое вызвало ф-ию.
               ;; (message ">>>>> (this-command-keys-vector): %S" (this-command-keys-vector))
               (if (with-timeout
                       ;;
                       (,interval
                        ;; прошло 0.3 сек., => было одинарное нажатие,
                        ;; выполним TIMEOUT-FORMS
                        (discard-input)
                        ,A
                        ,B
                        nil)
                     ;; не прошло 0.5 сек. Получили новое событие (произошло во время таймаута).
                     (let ((ev2 (read-key-sequence-vector  " ")))
                       ;; (message ">>>>>1 (read-key-sequence-vector  \" \"): %S" ev2)
                       ;; проверили на совпадение события из таймаута и вызвавшего события.
                       (double-keystroke-key-equal ev1 ev2)))
                     ;; Обязательно нужно выйти из `with-timeout', а то будет путаница с вызовом меню.
                   (progn
                     (call-interactively (quote ,def2)))
                 ))))
    fn-double))



(defun double-keystroke-key-equal (k1 k2)
  ""
  (let ((el10 (aref k1 0))
        (el20 (aref k2 0)))
    (cond
     ((= (length k1) 2)
      (if (or (= el10 3)   ;; C-c
              (= el10 8)   ;; C-h
              (= el10 24)) ;; C-x
          (eq (aref k1 1) el20)
        (equal k1 k2)))
     ((= (length k1) 3)
      (let ((el11 (aref k1 1)))
        (if (= el10 24)     ;; C-x
            (if (or (= el11 52)  ;; ctl-x-4-map
                    (= el11 53)  ;; ctl-x-5-map
                    (= el11 54)  ;; 2C-mode-map 
                    (= el11 118) ;; vc-prefix-map
                    (= el11 13)) ;; mule-keymap 
                (eq (aref k1 2) el20)))))
     (t
      (equal k1 k2)))))



;;;###autoload
(defun double-keystroke-unset-key (keymap key)
  ;;удалить ф-ию для двойного нажатия клавиши
  ""
  (let* ((key (double-keystroke-get-key-symbol key))
         (fn (lookup-key keymap key))
         (def1 (if (symbolp fn) (get fn 'double-keystroke-fn-single)))
         (def2 (if (symbolp fn) (get fn 'double-keystroke-fn-double))))

    (when def2
      (define-key keymap key nil)
      (and def1 (define-key keymap key def1))
      (fmakunbound fn)
      (unintern fn nil)
      )))



;;;###autoload
(defun double-keystroke-single-define-key (keymap key def)
  ;; позволяет изменять single-keystroke часть.
  ""
  (let* ((fn (lookup-key keymap key))
         (def2 (if (symbolp fn) (get fn 'double-keystroke-fn-double))))
    (if def2
        (let ((interval (get fn 'double-keystroke-interval))
              (doc (get fn 'double-keystroke-interval)))
          (define-key keymap key def)
          (double-keystroke-define-key keymap key def2 fn interval doc))
      (define-key keymap key def))))

;; От  advice  для `define-key'  отказался,  поскольку  в нем  нужно
;; делать затратный по времени поиск  в keymap, что приводит к очень
;; долгой загрузке  и старту,  например, ergoemacs-mode.  Для замены
;; single-keystroke действия служит ф-ия `double-keystroke-single-define-key'



;;
;; help
;;

(defun double-keystroke-help-add (fn)
  ""
  (let* ((fn1 (get fn 'double-keystroke-fn-single))
         (fn2 (get fn 'double-keystroke-fn-double))
         (i (get fn 'double-keystroke-interval))
         (b (get-buffer (help-buffer)))
         p)
    (when (and b i (or fn1 fn2))
      (with-current-buffer (help-buffer)
        (goto-char (point-max))
        (setq inhibit-read-only t)

        (princ "\n" b)
        (princ "Single keystroke function:\n    " b)
        (setq p (point))
        (princ fn1 b)
        (save-excursion ;; сделаем красивый ident
          (goto-char p)
          (indent-pp-sexp 1))
        (princ "\n" b)

        (princ "\n" b)
        (princ "Double keystroke function:\n    " b)
        (setq p (point))
        (princ fn2 b)
        (save-excursion ;; сделаем красивый ident
          (goto-char p)
          (indent-pp-sexp 1))
        (princ "\n" b)

        (princ "\n" b)
        (princ "Double keystroke interval:\n    " b)
        (setq p (point))
        (princ (format "%.3f" i) b)
        (save-excursion ;; сделаем красивый ident
          (goto-char p)
          (indent-pp-sexp 1))
        (princ "\n" b)

        (princ "\n" b)
        (princ ";; Body:\n " b)
        (setq p (point))
        (unwind-protect
            ;; (princ (symbol-function fn) b)
            (princ (indirect-function fn) b)
          (save-excursion ;; сделаем красивый ident
            (goto-char p)
            (indent-pp-sexp 1)))
        (princ "\n" b)

        (setq inhibit-read-only)))))



(defadvice describe-key (after double-keystroke-ad activate)
  ""
  (let* ((fn-name (car (reverse (split-string (describe-key-briefly (ad-get-arg 0))))))
         (fn (intern-soft fn-name)))
    (when fn (double-keystroke-help-add fn))))



(defadvice describe-function (after double-keystroke-ad activate)
  ""
  (double-keystroke-help-add (ad-get-arg 0)))



;;
;; utils
;;

(defun double-keystroke-get-key-symbol (key)
  ;;  Чтобы имена `double-keystroke-fn-' ф-ий при различных способах
  ;; задания key (например "C-a", "\C-a", [?\C-a], [(control ?a)])) оставались
  ;; одинаковыми.
  ;;  Можно использовать  `describe-key' (C-h k), чтобы получить нужную строку. 
  ""
  (cond
   ((vectorp key) (edmacro-parse-keys (key-description key) t))
   ((stringp key) (edmacro-parse-keys key t))
   (t (error "Error: in double-keystroke-get-key-symbol"))))



(defun double-keystroke-get-key-string (key)
  ;;
  ""
  (key-description (double-keystroke-get-key-symbol key)))




(provide 'double-keystroke)
;;; double-keystroke.el ends here
