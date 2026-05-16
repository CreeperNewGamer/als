# 📂 als (Advanced List Files)

A powerful, intelligent, and beautifully styled **Bash wrapper** for Linux and Termux that replaces the standard `ls` and `du` commands. It combines speed, visual clarity, and smart partition-tracking into a single, user-friendly utility.

---

## ✨ Features

* **📦 All-in-One Utility:** Seamlessly merges file listing (`ls`) and directory size calculation (`du`) into a single output.
* **🔗 Smart Symlink Tracking:** Automatically resolves Android and Linux shortcuts to show their true target sizes and paths.
* **🔒 Clean Error Handling:** Replaces jarring system permission errors with a polite, aligned `Locked` status tag.
* **🎨 Visual Hierarchy:** Built-in rounded tables with semantic ANSI color profiling for maximum readability at a glance.
* **🪶 Zero Dependencies:** Written entirely in plain shell script. Lightweight, fast, and works out-of-the-box on modern environments like Termux.

---

## 🚀 Quick Installation

To install **als** globally on your system, run this single command. It will download the utility, configure the system binary paths, and completely clean up after itself:

```bash
curl -sSfL https://github.com/CreeperNewGamer/als/raw/refs/heads/main/install.sh -o install.sh && chmod +x install.sh && ./install.sh
```

# Demo

![Demo](https://github.com/CreeperNewGamer/als/blob/main/Demo.gif?raw=true)

## 📜 License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. Feel free to use, modify, and distribute it, keeping the terminal open and free for everyone! See the `LICENSE` file for details.
