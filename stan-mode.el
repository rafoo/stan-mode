;; stan-mode.el --- Major mode for editing STAN files

;; Copyright (C) 2012, 2013  Jeffrey Arnold, Daniel Lee

;; Authors: Jeffrey Arnold <jeffrey.arnold@gmail.com>,
;;   Daniel Lee <bearlee@alum.mit.edu>
;; Maintainers: Jeffrey Arnold <jeffrey.arnold@gmail.com>,
;;   Daniel Lee <bearlee@alum.mit.edu>
;; URL: http://github.com/stan-dev/stan-mode
;; Keywords: languanges
;; Version: 1.0.00
;; Created: 2012-08-18

;; This file is not part of GNU Emacs.

;;; License:
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see
;; <http://www.gnu.org/licenses/>

;;; Commentary:
;;
;; This is a major mode for the Stan modeling language for Bayesian
;; statistics. See http://mc-stan.org/.
;;
;; To load this library:
;;
;;   (require 'stan-mode)
;;
;; This mode currently supports syntax-highlighting, indentation (via
;; the cc-mode indentation engine), imenu, and compiler-mode regular
;; expressions.
;;
;; Yasnippet and flymake support for stan are provided in separate
;; libraries included with stan-mode.
;;
;; Yasnippet support is provided in stan-snippets.
;;
;;   (require 'stan-snippets)
;;
;; Flymake support is provided in flymake-stan.
;;
;;   (require 'flymake-stan)

;;; Code:
(require 'font-lock)
(require 'cc-mode)
(require 'compile)

;;
;; Customizable Variables
;;
(defgroup stan-mode nil
  "A mode for Stan"
  :prefix "stan-"
  :group 'languages)

(defconst stan-mode-version "1.0.0"
  "stan-mode version number")

(defconst stan-language-version "1.2.0"
  "Stan language version supported")

(defcustom stan-mode-hook nil
  "Hook run when entering stan-mode"
  :type 'hook
  :group 'stan-mode)

(defcustom stan-comment-start "//"
  "Stan comment style to use"
  :type 'string
  :group 'stan-mode)

(defcustom stan-comment-end ""
  "Stan comment style to use"
  :type 'string
  :group 'stan-mode)

(defcustom stan-stanc-path
  "stanc"
  "Path to stanc executable"
  :type 'string
  :group 'stan-mode)

(defvar stan-output-buffer-name
  "*Stan*"
  "Buffer name for stan output")

;; (defvar stan-executable-suffix
;;   (cond ((or (eq system-type 'ms-dos)
;;              (eq system-type 'windows-nt)
;;              (eq system-type 'cygwin))
;;          ".exe")
;;         (t ""))
;;   "Suffix to use when compiling C++ code generated by Stan")

;; Abbrev

(defvar stan-mode-abbrev-table nil
  "Abbrev table used in stan-mode buffers.")

(define-abbrev-table 'stan-mode-abbrev-table ())

;; Font-Locks

;; <- and ~
(defvar stan-assign-regexp
  "\\(<-\\|~\\)"
  "Assigment operators")

(defvar stan-blocks-regexp
  (concat "^[[:space:]]*\\(model\\|data\\|transformed[ \t]+data\\|parameters"
          "\\|transformed[ \t]+parameters\\|generated[ \t]+quantities\\)[[:space:]]*{")
  "Stan blocks declaration regexp")

(defvar stan-types-list
   '("int" "real" "vector" "simplex" "ordered" "row_vector" "matrix"
     "corr_matrix" "cov_matrix" "positive_ordered")
   "Stan data types.")

(defvar stan-var-decl-regexp
  (concat (regexp-opt stan-types-list 'symbols)
          "\\(?:<.*?>\\)?\\(?:\\[.*?\\]\\)?[[:space:]]+\\([A-Za-z0-9_]+\\)")
    "Stan variable declaration regex")

(defvar stan-bounds-list
  '("upper" "lower")
  "Stan variable type bounds regexp")

(defvar stan-keywords-list
  '("for" "in" "lp__" "print" "if" "else" "while")
  "Stan keywords.")
;; handle truncation with a separate keyword

(defvar stan-functions-list
'("Phi" "Phi_approx" "abs" "acos" "acosh" "asin"
    "asinh" "atan" "atan2" "atanh" "binary_log_loss"
    "binomial_coefficient_log" "block" "cbrt" "ceil" "cholesky_decompose" 
    "col" "cols" "cos" "cosh" "crossprod" "cumulative_sum" "determinant" 
    "diag_matrix" "diag_post_multiply" "diag_pre_multiply" "diagonal" 
    "dims" "dot_product" "dot_self" "e" 
    "eigenvalues_sym" "eigenvectors_sym" "epsilon"
    "erf" "erfc" "exp" "exp2" "expm1" 
    "fabs" "fdim" "floor" "fma" "fmax" 
    "fmin" "fmod" "hypot" "if_else" 
    "int_step" "inv_cloglog" "inv_logit" "inverse" "lbeta" 
    "lgamma" "lmgamma" "log" "log10" "log1m" "log1m_inv_logit"
    "log1p" "log1p_exp" "log2" "log_determinant" "log_inv_logit"
    "log_sum_exp" "logit" 
    "max" "mdivide_left_tri_low" "mdivide_right_tri_low" "mean" 
    "min" "multiply_log" "multiply_lower_tri_self_transpose" 
    "negative_epsilon" "negative_infinity"
    "not_a_number" "pi" "positive_infinity" "pow" "prod" 
    "round" "row" "rows" "sd" "sin" "singular_values" 
    "sinh" "size" "softmax" "sqrt" "sqrt2" 
    "square" "step" "sum" "tan" "tanh" 
    "tcrossprod" "tgamma" "trace" "trunc" "variance")
  "Regular expression for builtin Stan functions (excluding distributions and cdfs)")

(defvar stan-distribution-list
  '("bernoulli" "bernoulli_logit" "beta_binomial" 
    "beta" "binomial" "categorical" "cauchy" "chi_square" "dirichlet"
    "double_exponential" "exponential" "gamma" "hypergeometric" 
    "inv_chi_square" "inv_gamma" 
    "inv_wishart" "lkj_corr_cholesky" "lkj_corr" "lkj_cov"
    "logistic" "lognormal" 
    "multi_normal_cholesky" "multi_normal" "multi_student_t"
    "multinomial" "neg_binomial" "normal" 
    "ordered_logistic"
    "pareto" "poisson" "poisson_log" "scaled_inv_chi_square" 
    "student_t" "uniform"
    "weibull" "wishart")
  "Regular expression for Stan distributions")

(defvar stan-cdf-list
  '("bernoulli_cdf" "beta_binomial_cdf" "beta_cdf" "binomial_cdf" 
    "exponential_cdf" "inv_chi_square_cdf" "inv_gamma_cdf" "logistic_cdf" 
    "lognormal_cdf" "neg_binomial_cdf" "normal_cdf" "pareto_cdf" 
    "poisson_cdf" "scaled_inv_chi_square_cdf" "student_t_cdf")
  "Regular expression for Stan cdf functions")

(defvar stan-c++-keywords
  '("alignas" "alignof" "and" "and_eq" "asm" "auto" "bitand" "bitor"
    "bool" "break" "case" "catch" "char" "char16_t" "char32_t" "class"
    "compl" "const" "constexpr" "const_cast" "continue" "decltype"
    "default" "delete" "do" "double" "dynamic_cast" "else" "enum"
    "explicit" "export" "extern" "false" "float" "for" "friend" "goto"
    "if" "inline" "int" "long" "mutable" "namespace" "new" "noexcept"
    "not" "not_eq" "nullptr" "operator" "or" "or_eq" "private" "protected"
    "public" "register" "reinterpret_cast" "return" "short" "signed"
    "sizeof" "static" "static_assert" "static_cast" "struct" "switch"
    "template" "this" "thread_local" "throw" "true" "try" "typedef"
    "typeid" "typename" "union" "unsigned" "using" "virtual" "void"
    "volatile" "wchar_t" "while" "xor" "xor_eq")
  "C++ reserved keywords. Stan variables cannot have these
  names." )

(defvar stan-operators
  '("||" "&&" "==" "!=" "<" "<=" ">" ">=" "+" "-" "*"
    "/" "\\" ".*" "./" "\\" "!" "'")
  "List of Stan operators

Stan Manual, v.1.1.0, Section 16.5, p. 100.
")

(defvar stan-font-lock-keywords
  `((,stan-blocks-regexp 1 font-lock-keyword-face)
    ;; Stan types. Look for it to come after the start of a line or semicolon.
    ( ,(concat "\\(^\\|;\\)\\s-*" (regexp-opt stan-types-list 'words)) 2 font-lock-type-face)
    (,stan-var-decl-regexp 2 font-lock-variable-name-face)
    (,(regexp-opt stan-keywords-list 'symbols) . font-lock-keyword-face)
    ("\\(T\\)\\[.*?\\]" 1 font-lock-keyword-face)
    ;; check that lower and upper appear after a < or ,
    (,(concat "\\(?:<\\|,\\)[[:space:]]*" (regexp-opt stan-bounds-list 'symbols))
     1 font-lock-keyword-face)
    (,(regexp-opt stan-functions-list 'symbols) . font-lock-function-name-face)
    ;; distribution names can only appear after a ~
    (,(concat "~[[:space:]]*" (regexp-opt stan-distribution-list 'symbols))
     1 font-lock-function-name-face)
    ;; distributions. Look for distribution_log after '<-'
    (,(concat "<-\\s-*\\(\\<" (regexp-opt stan-distribution-list) "_log\\>\\)") 
     1 font-lock-function-name-face)
    ;; cdfs come after '<-'
    (,(concat "<-[[:space:]]*" (regexp-opt stan-cdf-list 'symbols)) 
     1 font-lock-function-name-face)
    (,stan-assign-regexp . font-lock-reference-face)
    (,(regexp-opt stan-c++-keywords 'symbols) . font-lock-warning-face)
    ))

(defvar stan-compilation-error-regexp-alist
  '(("\\(.*?\\) LOCATION:[ \t]+file=\\([^;]+\\); +line=\\([0-9]+\\), +column=\\([0-9]+\\)" 1 2 3 4))
  "Regular expression matching error messages from the 'stanc' compiler.")

(setq compilation-error-regexp-alist
      (append stan-compilation-error-regexp-alist
              compilation-error-regexp-alist))

;;; Define Syntax table
(setq stan-mode-syntax-table (make-syntax-table c++-mode-syntax-table))
(modify-syntax-entry ?#  "< b"  stan-mode-syntax-table)
(modify-syntax-entry ?\n "> b"  stan-mode-syntax-table)
(modify-syntax-entry ?'  "." stan-mode-syntax-table)
;; _ should be part of symbol not word.
;; see
;; http://www.gnu.org/software/emacs/manual/html_node/elisp/Syntax-Class-Table.html#Syntax-Class-Table

(defun stan-version ()
  "Message the current stan-mode version"
  (interactive)
  (message "stan-mode version %s" stan-mode-version))

;; Compiling

(defun stan-path-to-cpp-file ()
  "For a Stan buffer, generate a path to the ouput C++ code."
  (if (buffer-file-name)
      (concat (file-name-sans-extension (buffer-file-name)) ".cpp")
    (make-temp-file "stan" nil ".cpp")))

;; (defun stan-path-to-exe-file ()
;;   "For a Stan buffer, generate a path to the output executable."
;;   (if (buffer-file-name)
;;       (concat (file-name-sans-extension (buffer-file-name))
;;               stan-executable-prefix)
;;     (make-temp-file "stan" nil stan-executable-prefix)))

(defun stan-model-name ()
  "For a Stan buffer, generate a path to output"
  (if (buffer-file-name)
      (file-name-sans-extension
       (file-name-nondirectory buffer-file-name))
    "anon_model"))

;; (setq stan-compile-output)

(defun stan-stanc-compile (input &optional output model-name)
  "Run stanc

Input is the path to the input function

Compile stan-model in file INPUT into a C++ file OUTPUT (if specified).
The C++ class will be named MODEL-NAME.

See the documenation for stanc.
"
  (let ((command stan-stanc-path))
    (if output
        (setq command (concat command (format " --output=%s " output))))
    (if model-name
        (setq command (concat command (format " --name=%s " model-name))))
    (setq command (concat command " " input))
    (message command)
    (shell-command command stan-output-buffer-name
                   stan-output-buffer-name)))

;; (defun stan-stanc-compile-buffer (&optional output model-name)
;;   "Run stanc on the current buffer"
;;   (interactive
;;    (list (read-string "output: " (stan-path-to-cpp-file) nil nil nil)
;;          (read-string "model-name: " (stan-model-name) nil nil nil)))
;;   (let ((input))
;;     ;; if buffer is a file: save file, use that file as input. if
;;     ;; buffer is not a file create a temporary file, and write buffer
;;     ;; contents to that.
;;     (if (setq input (buffer-file-name))
;;         (save-buffer)
;;       (setq input (make-temp-file "stan" nil ".stan"))
;;       (write-region nil nil input))
;;     (stan-stanc-compile input output model-name)))

;; Imenu tags
(defvar stan-imenu-generic-expression
  `(("Variable" ,stan-var-decl-regexp 2)
    ("Block" ,stan-blocks-regexp 1))
  "Stan mode imenu expression")

;; Keymap

(defvar stan-mode-map (make-sparse-keymap)
  "Keymap for Stan major mode")

;; Indenting
;; TODO:
;; Indentation notes
;; - Lines ending with ; are complete statements/expr
;; - If complete statement, indent at same level as previous
;;   complete statement
;; - If not complete statement, then indent to
;;   - open ( or [
;;   - <-, ~
;;   - else last lien
;; - If previous line ends in {, indent >>
;; - If previous line ends in }, indent <<
;; - If previous line begins with "for", indent >>
(defvar stan-style
  '("gnu"
    ;; # comments have syntatic class cpp-macro
    (c-offsets-alist . ((cpp-macro . 0)))))

(c-add-style "stan" stan-style)

;;
;; Define Major Mode
;;
(define-derived-mode stan-mode c++-mode "Stan"
  "A major mode for editing Stan files."
  :syntax-table stan-mode-syntax-table
  :abbrev-table stan-mode-abbrev-table
  :group 'stan-mode

  ;; syntax highlighting
  (setq font-lock-defaults '((stan-font-lock-keywords)))

  ;; comments
  (setq mode-name "Stan")
  ;;(setq comment-start stan-comment-start)
  (set (make-local-variable 'comment-start) stan-comment-start)
  (set (make-local-variable 'comment-end) stan-comment-end)
  ;; no tabs
  (setq indent-tabs-mode nil)
  ;; imenu
  (setq imenu-generic-expression stan-imenu-generic-expression)
  ;; indentation style
  (c-set-style "stan")
  )

(provide 'stan-mode)

;;; On Load
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.stan\\'" . stan-mode))

;;; stan-mode.el ends here
