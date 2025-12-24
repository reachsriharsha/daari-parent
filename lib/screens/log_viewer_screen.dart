import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../utils/app_logger.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  List<File> _logFiles = [];
  bool _isLoading = true;
  String? _selectedLevel;
  final List<String> _logLevels = ['ALL', 'DEBUG', 'INFO', 'WARNING', 'ERROR'];

  @override
  void initState() {
    super.initState();
    _loadLogFiles();
  }

  Future<void> _loadLogFiles() async {
    setState(() => _isLoading = true);
    try {
      final files = await logger.getLogFiles();
      // Sort by modification time (newest first)
      files.sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );
      setState(() {
        _logFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading logs: $e')));
      }
    }
  }

  Future<void> _clearAllLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs'),
        content: const Text(
          'Are you sure you want to delete all log files? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await logger.clearLogs();
        await _loadLogFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All logs cleared successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error clearing logs: $e')));
        }
      }
    }
  }

  Future<void> _shareAllLogs() async {
    if (_logFiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No log files to share')));
      return;
    }

    try {
      final files = _logFiles.map((f) => XFile(f.path)).toList();
      await Share.shareXFiles(
        files,
        subject:
            'Daari App Logs - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
        text: 'Debug logs from Daari app',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing logs: $e')));
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatFileName(String path) {
    return path.split(Platform.pathSeparator).last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by level',
            onSelected: (value) {
              setState(() {
                _selectedLevel = value == 'ALL' ? null : value;
              });
            },
            itemBuilder: (context) => _logLevels
                .map(
                  (level) => PopupMenuItem(
                    value: level,
                    child: Row(
                      children: [
                        if (level == (_selectedLevel ?? 'ALL'))
                          const Icon(Icons.check, size: 20),
                        if (level != (_selectedLevel ?? 'ALL'))
                          const SizedBox(width: 20),
                        const SizedBox(width: 8),
                        Text(level),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share all logs',
            onPressed: _logFiles.isEmpty ? null : _shareAllLogs,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadLogFiles,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logFiles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No log files found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Logs will appear here as you use the app',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                if (_selectedLevel != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.blue[50],
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filtering: $_selectedLevel',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedLevel = null),
                          child: const Text('Clear filter'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _logFiles.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) {
                      final file = _logFiles[index];
                      final stat = file.statSync();
                      final fileName = _formatFileName(file.path);
                      final fileSize = _formatFileSize(stat.size);
                      final modifiedDate = DateFormat(
                        'MMM dd, yyyy HH:mm',
                      ).format(stat.modified);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple[100],
                            child: Icon(
                              Icons.description,
                              color: Colors.deepPurple[700],
                            ),
                          ),
                          title: Text(
                            fileName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Size: $fileSize'),
                              Text('Modified: $modifiedDate'),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) async {
                              if (value == 'view') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => LogFileDetailScreen(
                                      file: file,
                                      filterLevel: _selectedLevel,
                                    ),
                                  ),
                                );
                              } else if (value == 'share') {
                                try {
                                  await Share.shareXFiles([
                                    XFile(file.path),
                                  ], subject: 'Log: $fileName');
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error sharing: $e'),
                                      ),
                                    );
                                  }
                                }
                              } else if (value == 'delete') {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Log File'),
                                    content: Text(
                                      'Delete $fileName? This cannot be undone.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  try {
                                    await file.delete();
                                    await _loadLogFiles();
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Log file deleted'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Error deleting: $e'),
                                        ),
                                      );
                                    }
                                  }
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'view',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility, size: 20),
                                    SizedBox(width: 8),
                                    Text('View'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.share, size: 20),
                                    SizedBox(width: 8),
                                    Text('Share'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 20,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LogFileDetailScreen(
                                  file: file,
                                  filterLevel: _selectedLevel,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: _logFiles.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _clearAllLogs,
              tooltip: 'Clear all logs',
              backgroundColor: Colors.red,
              child: const Icon(Icons.delete_sweep),
            ),
    );
  }
}

class LogFileDetailScreen extends StatefulWidget {
  final File file;
  final String? filterLevel;

  const LogFileDetailScreen({super.key, required this.file, this.filterLevel});

  @override
  State<LogFileDetailScreen> createState() => _LogFileDetailScreenState();
}

class _LogFileDetailScreenState extends State<LogFileDetailScreen> {
  String _content = '';
  bool _isLoading = true;
  String? _selectedLevel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.filterLevel;
    _loadContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    try {
      final content = await widget.file.readAsString();
      setState(() {
        _content = content;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error reading file: $e')));
      }
    }
  }

  String _getFilteredContent() {
    if (_selectedLevel == null) return _content;

    final lines = _content.split('\n');
    final filteredLines = lines.where((line) {
      return line.toUpperCase().contains('[$_selectedLevel]');
    }).toList();

    return filteredLines.join('\n');
  }

  int _getLineCount(String content) {
    return content.split('\n').length;
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.file.path.split(Platform.pathSeparator).last;
    final displayContent = _getFilteredContent();
    final totalLines = _getLineCount(_content);
    final filteredLines = _getLineCount(displayContent);

    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by level',
            onSelected: (value) {
              setState(() {
                _selectedLevel = value == 'ALL' ? null : value;
              });
            },
            itemBuilder: (context) =>
                ['ALL', 'DEBUG', 'INFO', 'WARNING', 'ERROR']
                    .map(
                      (level) => PopupMenuItem(
                        value: level,
                        child: Row(
                          children: [
                            if (level == (_selectedLevel ?? 'ALL'))
                              const Icon(Icons.check, size: 20),
                            if (level != (_selectedLevel ?? 'ALL'))
                              const SizedBox(width: 20),
                            const SizedBox(width: 8),
                            Text(level),
                          ],
                        ),
                      ),
                    )
                    .toList(),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () async {
              try {
                await Share.shareXFiles([
                  XFile(widget.file.path),
                ], subject: 'Log: $fileName');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error sharing: $e')));
                }
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[200],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedLevel == null
                              ? 'Showing all $totalLines lines'
                              : 'Showing $filteredLines of $totalLines lines ($_selectedLevel)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 20),
                            tooltip: 'Scroll to top',
                            onPressed: () {
                              _scrollController.animateTo(
                                0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 20),
                            tooltip: 'Scroll to bottom',
                            onPressed: () {
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: displayContent.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.filter_list_off,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No logs match the filter',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (_selectedLevel != null) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _selectedLevel = null),
                                  child: const Text('Clear filter'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            displayContent,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
