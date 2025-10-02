import fastapi
from fastapi import HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Dict, Optional
import uvicorn
from pydantic import BaseModel
import threading
import time
import uuid
from dataclasses import dataclass, field
from collections import defaultdict
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Models
class QueryModel(BaseModel):
    query: str

class ResponseModel(BaseModel):
    query_number: int
    response: str

class QueryNumberModel(BaseModel):
    query_number: int

class NodeRegistrationModel(BaseModel):
    node_capabilities: Dict = {}
    node_info: Dict = {}

# Data structures
@dataclass
class NodeInfo:
    node_id: str
    registration_time: float
    last_seen: float
    capabilities: Dict = field(default_factory=dict)
    info: Dict = field(default_factory=dict)
    queries_submitted: int = 0
    responses_provided: int = 0

@dataclass
class QueryInfo:
    query_number: int
    query: str
    submitter_node_id: str
    timestamp: float
    responses: List[Dict] = field(default_factory=list)
    assigned_nodes: List[str] = field(default_factory=list)
    max_responses: int = 3
    timeout: float = 180.0  # 3 minutes

class DistributedRoutingServer:
    def __init__(self):
        self.lock = threading.Lock()
        self.counter = 0
        self.nodes: Dict[str, NodeInfo] = {}
        self.queries: Dict[int, QueryInfo] = {}
        self.pending_queries: List[int] = []
        
        # Configuration
        self.max_queries_per_node = 5
        self.node_timeout = 300  # 5 minutes
        self.query_timeout = 180  # 3 minutes
        self.max_responses_per_query = 3  # Fixed the typo here
        self.max_memory_size = 1000  # Maximum queries to keep in memory
        
        # Start background cleanup
        self._start_cleanup_thread()
    
    def _start_cleanup_thread(self):
        """Start background thread for periodic cleanup"""
        def cleanup_worker():
            while True:
                try:
                    time.sleep(30)  # Run every 30 seconds
                    self._cleanup_expired_data()
                except Exception as e:
                    logger.error(f"Cleanup worker error: {e}")
        
        cleanup_thread = threading.Thread(target=cleanup_worker, daemon=True)
        cleanup_thread.start()
        logger.info("Cleanup thread started")
    
    def _cleanup_expired_data(self):
        """Clean up expired queries and inactive nodes"""
        current_time = time.time()
        
        with self.lock:
            # Clean up expired queries
            expired_queries = []
            for query_id, query_info in self.queries.items():
                if current_time - query_info.timestamp > query_info.timeout:
                    expired_queries.append(query_id)
            
            for query_id in expired_queries:
                logger.info(f"Cleaning up expired query: {query_id}")
                del self.queries[query_id]
                if query_id in self.pending_queries:
                    self.pending_queries.remove(query_id)
            
            # Clean up inactive nodes
            inactive_nodes = []
            for node_id, node_info in self.nodes.items():
                if current_time - node_info.last_seen > self.node_timeout:
                    inactive_nodes.append(node_id)
            
            for node_id in inactive_nodes:
                logger.info(f"Removing inactive node: {node_id}")
                del self.nodes[node_id]
            
            # Limit memory usage
            if len(self.queries) > self.max_memory_size:
                # Remove oldest queries
                oldest_queries = sorted(self.queries.items(), 
                                      key=lambda x: x[1].timestamp)[:len(self.queries) - self.max_memory_size]
                
                for query_id, _ in oldest_queries:
                    del self.queries[query_id]
                    if query_id in self.pending_queries:
                        self.pending_queries.remove(query_id)
            
            if expired_queries or inactive_nodes:
                logger.info(f"Cleanup completed: {len(expired_queries)} queries, {len(inactive_nodes)} nodes removed")
    
    def _generate_node_id(self) -> str:
        """Generate unique node ID"""
        return f"node_{uuid.uuid4().hex[:8]}"
    
    def _register_or_update_node(self, node_id: str, capabilities: Dict = None, info: Dict = None):
        """Register new node or update existing one"""
        current_time = time.time()
        
        if node_id not in self.nodes:
            self.nodes[node_id] = NodeInfo(
                node_id=node_id,
                registration_time=current_time,
                last_seen=current_time,
                capabilities=capabilities or {},
                info=info or {}
            )
            logger.info(f"New node registered: {node_id}")
        else:
            self.nodes[node_id].last_seen = current_time
            if capabilities:
                self.nodes[node_id].capabilities.update(capabilities)
            if info:
                self.nodes[node_id].info.update(info)
    
    def _get_available_nodes_for_query(self, submitter_node_id: str, max_nodes: int = None) -> List[str]:
        """Get list of nodes that can process the query (excluding submitter)"""
        if max_nodes is None:
            max_nodes = self.max_responses_per_query
        
        available_nodes = []
        current_time = time.time()
        
        for node_id, node_info in self.nodes.items():
            # Skip submitter node
            if node_id == submitter_node_id:
                continue
            
            # Skip inactive nodes
            if current_time - node_info.last_seen > self.node_timeout:
                continue
            
            # Check if node is not overloaded
            active_queries = sum(1 for q in self.queries.values() 
                               if node_id in q.assigned_nodes)
            if active_queries < self.max_queries_per_node:
                available_nodes.append(node_id)
        
        # Return limited number of nodes
        return available_nodes[:max_nodes]

# Global server instance
server = DistributedRoutingServer()
app = fastapi.FastAPI(title="Enhanced Distributed LLM Routing Server", version="2.0.0")

@app.middleware("http")
async def add_node_id_header(request, call_next):
    """Middleware to handle node identification"""
    try:
        response = await call_next(request)
        
        # Add node ID to response headers if present in request
        node_id = request.headers.get("x-node-id")
        if node_id:
            response.headers["x-node-id"] = node_id
        
        return response
    except Exception as e:
        logger.error(f"Middleware error: {e}")
        raise

@app.get("/")
def root():
    return {
        "message": "Enhanced Distributed LLM Routing Server is running!",
        "status": "healthy",
        "version": "2.0.0",
        "features": [
            "Node identification and management",
            "Self-query prevention", 
            "Automatic cleanup",
            "Query timeout handling",
            "Load balancing"
        ]
    }

@app.post("/register")
def register_node(
    registration: NodeRegistrationModel,
    x_node_id: Optional[str] = Header(None)
) -> Dict:
    """Register a new node or update existing node information"""
    try:
        with server.lock:
            # Generate new node ID if not provided
            if not x_node_id:
                node_id = server._generate_node_id()
            else:
                node_id = x_node_id
            
            server._register_or_update_node(
                node_id, 
                registration.node_capabilities,
                registration.node_info
            )
            
            logger.info(f"Node registered/updated: {node_id}")
            
            return {
                "node_id": node_id,
                "status": "registered",
                "message": "Node registered successfully"
            }
    
    except Exception as e:
        logger.error(f"Error in register_node: {str(e)}")
        raise HTTPException(status_code=500, detail="Error registering node")

@app.get("/request")
def get_requests(x_node_id: Optional[str] = Header(None)) -> List[Dict]:
    """Get pending queries for a specific node to process"""
    try:
        if not x_node_id:
            return []
        
        with server.lock:
            # Update node last seen
            server._register_or_update_node(x_node_id)
            
            available_queries = []
            
            for query_id in server.pending_queries[:]:  # Copy list to avoid modification during iteration
                query_info = server.queries.get(query_id)
                if not query_info:
                    server.pending_queries.remove(query_id)
                    continue
                
                # Skip if this node submitted the query
                if query_info.submitter_node_id == x_node_id:
                    continue
                
                # Skip if node is already assigned to this query
                if x_node_id in query_info.assigned_nodes:
                    continue
                
                # Skip if query has enough responses
                if len(query_info.responses) >= query_info.max_responses:
                    server.pending_queries.remove(query_id)
                    continue
                
                # Check if query is expired
                if time.time() - query_info.timestamp > query_info.timeout:
                    server.pending_queries.remove(query_id)
                    del server.queries[query_id]
                    continue
                
                # Assign node to query
                query_info.assigned_nodes.append(x_node_id)
                
                available_queries.append({
                    "query_number": query_info.query_number,
                    "query": query_info.query,
                    "timestamp": query_info.timestamp,
                    "metadata": {
                        "max_responses": query_info.max_responses,
                        "current_responses": len(query_info.responses),
                        "timeout": query_info.timeout
                    }
                })
                
                # Limit queries per request
                if len(available_queries) >= 3:
                    break
            
            logger.debug(f"Node {x_node_id} received {len(available_queries)} queries")
            return available_queries
    
    except Exception as e:
        logger.error(f"Error in get_requests: {str(e)}")
        return []

@app.post("/query")
def submit_query(
    query_model: QueryModel,
    x_node_id: Optional[str] = Header(None)
) -> Dict:
    """Submit a new query and get query number"""
    try:
        with server.lock:
            # Get or create node ID
            if not x_node_id:
                x_node_id = server._generate_node_id()
            
            # Register/update node
            server._register_or_update_node(x_node_id)
            
            # Increment counter and create query
            server.counter += 1
            query_info = QueryInfo(
                query_number=server.counter,
                query=query_model.query,
                submitter_node_id=x_node_id,
                timestamp=time.time(),
                max_responses=server.max_responses_per_query
            )
            
            server.queries[server.counter] = query_info
            server.pending_queries.append(server.counter)
            
            # Update node stats
            server.nodes[x_node_id].queries_submitted += 1
            
            logger.info(f"Query submitted - ID: {server.counter}, Node: {x_node_id}, Query: {query_model.query[:50]}...")
            
            return {
                "query_number": server.counter,
                "node_id": x_node_id,
                "status": "submitted",
                "estimated_wait_time": len(server.pending_queries) * 5  # Rough estimate in seconds
            }
    
    except Exception as e:
        logger.error(f"Error in submit_query: {str(e)}")
        raise HTTPException(status_code=500, detail="Error processing query")

@app.get("/response")
def get_responses(
    query_number: int,
    x_node_id: Optional[str] = Header(None)
) -> List[str]:
    """Get all responses for a specific query number"""
    try:
        with server.lock:
            query_info = server.queries.get(query_number)
            if not query_info:
                return []
            
            # Only allow submitter to get responses
            if x_node_id and query_info.submitter_node_id != x_node_id:
                logger.warning(f"Unauthorized access: Node {x_node_id} tried to access query {query_number} from {query_info.submitter_node_id}")
                raise HTTPException(status_code=403, detail="Not authorized to access this query")
            
            responses = [r["response"] for r in query_info.responses]
            logger.debug(f"Retrieved {len(responses)} responses for query {query_number}")
            
            return responses
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in get_responses: {str(e)}")
        return []

@app.post("/response")
def submit_response(
    data: ResponseModel,
    x_node_id: Optional[str] = Header(None)
):
    """Submit a response for a query"""
    try:
        query_number = data.query_number
        new_response = data.response
        
        if not x_node_id:
            raise HTTPException(status_code=400, detail="Node ID required")
        
        with server.lock:
            query_info = server.queries.get(query_number)
            if not query_info:
                raise HTTPException(status_code=404, detail="Query not found")
            
            # Prevent self-response
            if query_info.submitter_node_id == x_node_id:
                logger.warning(f"Self-response blocked: Node {x_node_id} query {query_number}")
                raise HTTPException(status_code=400, detail="Cannot respond to your own query")
            
            # Check if node was assigned to this query
            if x_node_id not in query_info.assigned_nodes:
                logger.warning(f"Unassigned response: Node {x_node_id} query {query_number}")
                raise HTTPException(status_code=400, detail="Node not assigned to this query")
            
            # Check if already responded
            for existing_response in query_info.responses:
                if existing_response.get("node_id") == x_node_id:
                    logger.warning(f"Duplicate response: Node {x_node_id} query {query_number}")
                    raise HTTPException(status_code=400, detail="Already responded to this query")
            
            # Add response
            query_info.responses.append({
                "node_id": x_node_id,
                "response": new_response,
                "timestamp": time.time()
            })
            
            # Update node stats
            if x_node_id in server.nodes:
                server.nodes[x_node_id].responses_provided += 1
            
            # Remove from pending if enough responses
            if len(query_info.responses) >= query_info.max_responses:
                if query_number in server.pending_queries:
                    server.pending_queries.remove(query_number)
            
            logger.info(f"Response added: query {query_number} by node {x_node_id}")
            
            return {
                "message": "Response received successfully",
                "query_number": query_number,
                "node_id": x_node_id,
                "total_responses": len(query_info.responses)
            }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in submit_response: {str(e)}")
        raise HTTPException(status_code=500, detail="Error processing response")

@app.post("/end")
def end_query(
    data: QueryNumberModel,
    x_node_id: Optional[str] = Header(None)
) -> Dict:
    """Clean up completed query and its responses"""
    try:
        query_number = data.query_number
        
        with server.lock:
            query_info = server.queries.get(query_number)
            if not query_info:
                return {"success": False, "message": "Query not found"}
            
            # Only allow submitter to end the query
            if x_node_id and query_info.submitter_node_id != x_node_id:
                raise HTTPException(status_code=403, detail="Not authorized to end this query")
            
            # Remove from pending queries
            if query_number in server.pending_queries:
                server.pending_queries.remove(query_number)
            
            # Remove query
            del server.queries[query_number]
            
            logger.info(f"Query {query_number} ended by node {x_node_id}")
            
            return {
                "success": True,
                "query_number": query_number,
                "message": "Query ended successfully"
            }
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in end_query: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error ending query: {str(e)}")

@app.get("/status")
def get_status(x_node_id: Optional[str] = Header(None)):
    """Get current server status and statistics"""
    with server.lock:
        # Update node last seen if provided
        if x_node_id:
            server._register_or_update_node(x_node_id)
        
        return {
            "server_status": "running",
            "version": "2.0.0",
            "active_nodes": len(server.nodes),
            "active_queries": len(server.queries),
            "pending_queries": len(server.pending_queries),
            "total_queries_processed": server.counter,
            "timestamp": time.time(),
            "configuration": {
                "max_queries_per_node": server.max_queries_per_node,
                "node_timeout": server.node_timeout,
                "query_timeout": server.query_timeout,
                "max_responses_per_query": server.max_responses_per_query  # Fixed typo
            },
            "nodes_info": [
                {
                    "node_id": node.node_id,
                    "last_seen": time.time() - node.last_seen,
                    "queries_submitted": node.queries_submitted,
                    "responses_provided": node.responses_provided,
                    "capabilities": node.capabilities
                }
                for node in server.nodes.values()
            ],
            "queries_summary": [
                {
                    "id": q.query_number,
                    "submitter": q.submitter_node_id,
                    "responses_count": len(q.responses),
                    "assigned_nodes": len(q.assigned_nodes),
                    "age": time.time() - q.timestamp
                }
                for q in server.queries.values()
            ]
        }

@app.get("/health")
def health_check():
    """Simple health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "uptime": time.time(),
        "active_nodes": len(server.nodes),
        "active_queries": len(server.queries)
    }

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

if __name__ == "__main__":
    print("=" * 60)
    print("🚀 Starting Enhanced Distributed LLM Routing Server v2.0.0")
    print("=" * 60)
    print("🌟 Features:")
    print("   • Node identification and management")
    print("   • Self-query prevention")
    print("   • Automatic cleanup and memory management")
    print("   • Query timeout handling")
    print("   • Load balancing and node assignment")
    print("   • Enhanced security and authorization")
    print()
    print("📡 Server endpoints:")
    print("   • Main: http://0.0.0.0:8313")
    print("   • Status: http://0.0.0.0:8313/status")
    print("   • Health: http://0.0.0.0:8313/health")
    print("   • Docs: http://0.0.0.0:8313/docs")
    print("=" * 60)
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8313,
        log_level="info"
    )