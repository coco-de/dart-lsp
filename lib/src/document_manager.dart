/// Document manager for tracking open documents
class DocumentManager {
  final Map<String, String> _documents = {};
  
  /// Open a document
  void openDocument(String uri, String content) {
    _documents[uri] = content;
  }
  
  /// Update a document
  void updateDocument(String uri, String content) {
    _documents[uri] = content;
  }
  
  /// Close a document
  void closeDocument(String uri) {
    _documents.remove(uri);
  }
  
  /// Get document content
  String? getDocument(String uri) {
    return _documents[uri];
  }
  
  /// Check if document is open
  bool isOpen(String uri) {
    return _documents.containsKey(uri);
  }
  
  /// Get all open documents
  Iterable<String> get openDocuments => _documents.keys;
}
