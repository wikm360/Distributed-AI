# Distributed AI Chat (DAI)

A research project implementing a distributed AI chat system with RAG (Retrieval-Augmented Generation) capabilities, supporting multiple AI models and edge computing.

## ⚠️ License Notice

**This is a proprietary research project. All rights reserved.**

This software is protected by copyright and is made available under a proprietary research license. Unauthorized copying, distribution, or commercial use is strictly prohibited.

**Key License Terms:**
- ✅ **Research & Education**: Free to use for research and educational purposes
- ✅ **Contributions Welcome**: You can contribute improvements via pull requests
- ❌ **Commercial Use**: Prohibited without explicit written permission
- ❌ **Distribution**: You may not distribute or publish this software
- ❌ **Standalone Copies**: You may not create independent forks for distribution

For complete license terms, please see [LICENSE](LICENSE) file.

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## ✨ Features

- **Multiple AI Models**: Support for Gemma, DeepSeek, Llama, and other models
- **Distributed Computing**: Local and distributed processing modes
- **RAG System**: Retrieval-Augmented Generation with document management
- **Edge AI**: On-device AI processing with Flutter Gemma
- **Modern UI**: Optimized, fast, and user-friendly interface
- **Document Management**: Import and manage documents for RAG queries

## 🏗️ Architecture

```
├── 🎨 frontend/              # UI Layer
│   ├── screens/              # Application screens
│   ├── widgets/              # Reusable UI components
│   └── controllers/          # UI controllers
├── 🔧 backend/               # AI Engine Layer
│   ├── ai_engine.dart        # Base AI engine interface
│   ├── gemma_engine.dart     # Flutter Gemma implementation
│   └── llama_engine.dart     # LlamaCpp implementation
├── 🌐 network/               # Distributed System
│   ├── distributed_manager.dart
│   ├── rag_worker.dart
│   └── routing_client.dart
├── 📚 rag/                   # RAG System
│   ├── rag_manager.dart
│   ├── embedding_service.dart
│   └── text_chunker.dart
└── 📦 shared/                # Shared utilities
    ├── models.dart
    └── logger.dart
```

## 🚀 Installation

### Prerequisites

- Flutter SDK (>=3.24.0)
- Dart SDK (>=3.5.0)

### Setup

1. Clone the repository:
```bash
git clone [repository-url]
cd distributed-ai
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the application:
```bash
flutter run
```

## 📖 Usage

### Running the Application

```bash
# Mobile (Android/iOS)
flutter run

# Desktop
flutter run -d windows
flutter run -d macos
flutter run -d linux

# Web
flutter run -d web
```

### Key Features Usage

1. **Model Selection**: Browse and select AI models from the home screen
2. **Download Models**: Download required models before use
3. **Chat Interface**: Start conversations with selected models
4. **Document Management**: Import documents in the Backpack screen
5. **RAG Queries**: Use RAG system for context-aware responses
6. **Distributed Mode**: Toggle between local and distributed processing

## 🤝 Contributing

We welcome contributions to this research project!

**Important**: By contributing, you acknowledge that:
- Your contributions become the property of the project owner
- You grant a perpetual license to use your contributions
- This is a research project, not traditional open-source

### How to Contribute

1. Fork the repository (for contribution purposes only)
2. Create a feature branch
3. Make your changes
4. Submit a pull request

For detailed contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

### Contribution Areas

- 🐛 Bug fixes
- ⚡ Performance improvements
- 🎨 UI/UX enhancements
- 📝 Documentation
- 🔧 Code quality improvements
- ✨ New features aligned with research goals

## 📄 License

This project is licensed under a **Proprietary Research License**.

**Copyright (c) 2024 [Your Name/Organization]. All rights reserved.**

### License Summary

- **Research & Education**: ✅ Allowed
- **Contributions**: ✅ Welcome via pull requests
- **Commercial Use**: ❌ Prohibited
- **Distribution**: ❌ Prohibited
- **Standalone Copies**: ❌ Prohibited

For complete license terms and conditions, please read the [LICENSE](LICENSE) file.

### Research Use

If you use this project in your research:
- Please cite the project appropriately
- Acknowledge the project in your publications
- Share your findings and improvements back to the project

## 📧 Contact

For questions, licensing inquiries, or collaboration opportunities:

- **Email**: [Your Email]
- **Repository**: [Repository URL]
- **Issues**: [GitHub Issues URL]

## 🙏 Acknowledgments

- Flutter Gemma team for edge AI capabilities
- All contributors who have helped improve this project
- Research community for feedback and suggestions

## ⚠️ Disclaimer

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.

---

**Note**: This is a research project. For commercial licensing or special use cases, please contact the project owner.

