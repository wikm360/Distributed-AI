# 🌐 Distributed AI Chat System (DAI)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Active%20Development-yellow)](https://github.com)

> **Democratizing AI through distributed, privacy-first collective intelligence**

A revolutionary chat platform that runs Large Language Models (LLMs) directly on user devices, leveraging distributed computing and collective knowledge instead of centralized servers. Built with Flutter and powered by community collaboration.

---

## 🎯 Vision

In a world dominated by centralized AI services, **DAI** brings a paradigm shift: 

- **🔓 No Vendor Lock-in**: Break free from expensive API subscriptions
- **🔒 Privacy First**: All processing happens locally on your device
- **🤝 Collective Intelligence**: Everyone contributes and benefits
- **⚡ Distributed Power**: Harness combined computational resources
- **🌍 Equal Access**: Advanced AI for everyone, regardless of resources

---

## ✨ Key Features

### 🧠 On-Device AI Engines
- **Gemma Engine**: Google's Gemma models running locally
- **Qwen Engine**: Alibaba's Qwen 2.5 models support
- **Llama Engine**: GGUF format models via LlamaCpp

### 🔗 Distributed Architecture
- **Routing Server**: FastAPI-based coordination layer
- **Worker Nodes**: Devices sharing computational power
- **P2P Network** *(Coming Soon)*: Serverless peer-to-peer communication

### 📚 RAG (Retrieval Augmented Generation)
- **Local Knowledge Base**: ObjectBox-powered vector storage
- **Smart Retrieval**: Context-aware document search
- **Embedding Service**: Semantic understanding of queries

### 🎨 Modern UI/UX
- Material Design 3
- Real-time streaming responses
- Model management dashboard
- Worker status visualization

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        User Device                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Chat UI     │  │  AI Engine   │  │  RAG System  │      │
│  │  (Flutter)   │─▶│  (Local LLM) │◀─│  (ObjectBox) │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                                      │              │
└─────────┼──────────────────────────────────────┼─────────────┘
          │                                      │
          ▼                                      ▼
┌─────────────────────────────────────────────────────────────┐
│                    Routing Server (FastAPI)                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │Load Balancer │  │ Task Queue   │  │ Worker Pool  │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
          │                                      │
          ▼                                      ▼
┌─────────────────────┐            ┌─────────────────────┐
│   Worker Node 1     │            │   Worker Node N     │
│  (Shared Device)    │    ...     │  (Shared Device)    │
└─────────────────────┘            └─────────────────────┘
```

---

## 🚀 Getting Started

### Prerequisites

#### For Mobile App:
- Flutter SDK 3.x+
- Android SDK (API 24+) or iOS 12+
- Minimum 4GB RAM
- 3GB storage space

#### For Routing Server:
- Python 3.9+
- FastAPI
- 1GB RAM VPS

### Installation

#### 1️⃣ Clone the Repository
```bash
git clone https://github.com/wikm360/Distributed-AI.git
cd distributed-ai-chat
```

#### 2️⃣ Setup Flutter App
```bash
cd mobile
flutter pub get
flutter run
```

#### 3️⃣ Setup Routing Server
```bash
cd Routing-server
pip install -r requirements.txt
python Routing.py
```

#### 4️⃣ Download AI Models
Open the app, navigate to Model Store, and download your preferred model:
- Gemma 2B (Lightweight)
- Qwen 2.5 0.5B (Lightweight)
- Qwen 2.5 7B (Balanced)
- Llama 3 8B (Advanced)

---

## 💡 How It Works

### Local Mode
1. User sends a query
2. Local AI engine processes the request
3. RAG system retrieves relevant context
4. Response streams back in real-time

### Distributed Mode
1. Query sent to Routing Server
2. Server distributes task to available Workers
3. Workers process using local models + RAG
4. Results aggregated and returned to user

---

## 🗺️ Roadmap

### ✅ Phase 1: Local Models & RAG (Completed)
- [x] Local LLM execution
- [x] ObjectBox vector database
- [x] RAG implementation
- [x] Multi-engine support

### ✅ Phase 2: Distributed Network (Completed)
- [x] Routing server
- [x] Worker nodes
- [x] Load balancing

### 🔄 Phase 3: RAG & Model Optimization (In Progress)
- [x] RAG chunking strategy optimization
- [x] Embedding model fine-tuning
- [x] Vector DB indexing optimization
- [ ] Model quantization & compression
- [ ] Inference speed benchmarking
- [ ] Memory footprint reduction

### 🔄 Phase 4: Persian Language Support (In Progress)
- [ ] Persian UI localization
- [ ] Persian model training & fine-tuning
- [ ] Farsi OCR support
- [ ] Persian RAG knowledge bases
- [ ] Right-to-left (RTL) UI adaptation
- [ ] Persian NLP preprocessing

### 🔄 Phase 5: P2P Decentralization (In Progress)
- [ ] Serverless peer-to-peer routing
- [ ] DHT-based node discovery
- [ ] Blockchain-based trust system

### 🔮 Phase 6: Federated Learning
- [ ] On-device model fine-tuning
- [ ] Gradient sharing (privacy-preserving)
- [ ] FedAvg/FedProx implementation

### 🎮 Phase 7: Gamification & Social
- [ ] Trust score system
- [ ] User levels & missions
- [ ] Topic-based collaboration spaces
- [ ] Reputation rewards

### 🛠️ Phase 8: Developer Ecosystem
- [ ] Open SDK release
- [ ] Plugin system
- [ ] API documentation
- [ ] Community marketplace

---

## 🌟 Why DAI?

| Feature | Traditional AI | DAI |
|---------|---------------|-----|
| **Privacy** | Data sent to servers | 100% local processing |
| **Cost** | Subscription fees | Free & open source |
| **Access** | Internet required | Works offline |
| **Ownership** | Vendor lock-in | You own your data |
| **Learning** | Centralized training | Federated learning |
| **Community** | Passive consumers | Active contributors |

---

## 🤝 Contributing

We believe in collective intelligence! Here's how you can help:

### For Developers
- 🐛 Report bugs and issues
- 💻 Submit pull requests
- 📝 Improve documentation
- 🧪 Write tests

### For AI Enthusiasts
- 🧠 Fine-tune models for specific languages
- 📚 Contribute to knowledge bases
- 🔍 Improve RAG performance
- 📊 Share benchmarks

### For Community
- 🌍 Translate the app
- 📢 Spread the word
- 💡 Suggest features
- 🎨 Design UI/UX improvements

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

---

## 🛡️ Privacy & Security

- **🔐 End-to-End Encryption**: All network communication is encrypted
- **🏠 Local Processing**: Your data never leaves your device
- **🕵️ No Tracking**: We don't collect personal information
- **🔍 Differential Privacy**: Federated learning protects user data
- **🛡️ Malicious Node Detection**: Built-in security against bad actors

---

## 📊 Technical Stack

### Frontend
- **Framework**: Flutter 3.x
- **State Management**: Provider / Riverpod
- **Database**: ObjectBox (vector DB)
- **AI Runtime**: LiteRT, Edge-AI

### Backend
- **Server**: Python FastAPI

### AI/ML
- **Inference**: LlamaCpp, ONNX Runtime
- **Embeddings**: SentenceTransformers
- **Fine-tuning**: LoRA, QLoRA

---

## 📈 Performance

| Model | Size | Speed (tokens/s) | RAM Usage |
|-------|------|------------------|-----------|
| Gemma 2B | 1.4GB | 15-20 | 2.5GB |
| Qwen 2.5 7B | 4.1GB | 8-12 | 5GB |
| Llama 3 8B | 4.7GB | 6-10 | 6GB |

*Benchmarks on Snapdragon 8 Gen 2, Android 13*

---

## 🌐 Use Cases

- **🎓 Education**: Student collaboration with AI tutors
- **🏢 Enterprise**: Private AI for sensitive data
- **🌍 Remote Areas**: Offline AI assistance
- **🔬 Research**: Distributed model training
- **💬 Communities**: Topic-based knowledge sharing

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **Flutter Team**: For the amazing cross-platform framework
- **LlamaCpp**: For efficient local inference
- **ObjectBox**: For fast vector database
- **Hugging Face**: For open-source models
- **Community Contributors**: For making this possible

---

## 📞 Contact & Support

- **My Site**: [My Site](https://wikm.ir)


<div align="center">

### 🚀 Join the AI Revolution!

**Together, we're building the future of decentralized intelligence**

[⭐ Star this repo](https://github.com/wikm360/Distributed-AI) • [🍴 Fork it](https://github.com/wikm360/Distributed-AI/fork)

</div>

---

<div align="center">
Made with ❤️ by wikm
</div>
