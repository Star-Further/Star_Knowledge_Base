import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_math_fork/flutter_math.dart';
import 'config.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '星知库',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'HarmonyOS', // 启用鸿蒙字体
      ),
      home: const MainScaffold(),
    );
  }
}

// ================= 公式渲染组件 =================
class MathText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const MathText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final regExp = RegExp(r'\$\$(.+?)\$\$|\$(.+?)\$');
    final matches = regExp.allMatches(text);
    List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: style));
      }
      String mathText = (match.group(1) ?? match.group(2) ?? '').replaceAll('\\lt', '<').replaceAll('\\gt', '>');
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Math.tex(mathText, textStyle: style ?? const TextStyle(fontSize: 14),
            onErrorFallback: (error) => Text(mathText, style: style),
          ),
        ),
      ));
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
    }
    return Text.rich(TextSpan(children: spans), style: style);
  }
}

// ================= 主页（包含底部导航） =================
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});
  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0 ? const KnowledgePage() : const FavoritePage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: '知识库'),
          NavigationDestination(icon: Icon(Icons.star), label: '错题本'),
        ],
      ),
    );
  }
}

// ================= 单张卡片组件（带收藏和删除） =================
class QuestionCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback onRefresh;

  const QuestionCard({super.key, required this.item, required this.onRefresh});

  Future<void> _deleteRecord(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后不可恢复，确定要删除这道题吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await http.delete(Uri.parse('$kApiBaseUrl/record/${item['id']}'));
        onRefresh();
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败')));
      }
    }
  }

  Future<void> _toggleFavorite(BuildContext context) async {
    try {
      await http.post(Uri.parse('$kApiBaseUrl/record/${item['id']}/favorite'));
      onRefresh();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('操作失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    var content = item['content_json'];
    bool isFav = item['is_favorite'] == 1;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📝 记录 #${item['id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(isFav ? Icons.star : Icons.star_border, color: Colors.amber),
                      onPressed: () => _toggleFavorite(context),
                      tooltip: isFav ? '取消收藏' : '加入错题本',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _deleteRecord(context),
                      tooltip: '删除',
                    ),
                  ],
                )
              ],
            ),
            const Divider(),
            
            // 知识点
            const Text('💡 知识点精讲：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            ...(content['knowledge_points'] as List).map((kp) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: const Border(left: BorderSide(color: Colors.orange, width: 4)),
                  borderRadius: BorderRadius.circular(4)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📌 ${kp['title']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 15)),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.5),
                        children: [
                          const TextSpan(text: '概念：', style: TextStyle(fontWeight: FontWeight.bold)),
                          WidgetSpan(alignment: PlaceholderAlignment.middle, child: MathText(kp['concept'] ?? ''))
                        ]
                      )
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.green, fontSize: 14, height: 1.5),
                        children: [
                          const TextSpan(text: '用法：', style: TextStyle(fontWeight: FontWeight.bold)),
                          WidgetSpan(alignment: PlaceholderAlignment.middle, child: MathText(kp['usage'] ?? ''))
                        ]
                      )
                    ),
                  ],
                ),
              );
            }).toList(),
            
            const SizedBox(height: 12),
            const Text('📐 核心公式：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: (content['formulas'] as List).map((f) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                  child: MathText('$f', style: const TextStyle(fontSize: 15)),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            const Text('🛠 解题思路与方法：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: MathText('${content['solution_method']}', style: const TextStyle(height: 1.6)),
            ),
            
            const SizedBox(height: 16),
            const Text('🚀 举一反三：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ...(content['similar_questions'] as List).map((sq) {
              return Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8)
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MathText('变式题：${sq['question']}', style: const TextStyle(fontWeight: FontWeight.w500, height: 1.5)),
                    const SizedBox(height: 8),
                    MathText('解析：${sq['answer']}', style: const TextStyle(color: Colors.green, height: 1.5)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

// ================= 知识库页面 =================
class KnowledgePage extends StatefulWidget {
  const KnowledgePage({super.key});
  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  List<dynamic> allData = [];
  bool isLoading = true;
  bool isParsing = false;
  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchKeyword = "";

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final url = Uri.parse('$kApiBaseUrl/knowledge_tree?keyword=$_searchKeyword');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          allData = jsonData['data'];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> parseNewLink() async {
    String link = _linkController.text.trim();
    if (link.isEmpty || !link.contains('deepseek.com/share/')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入正确的 DeepSeek 链接')));
      return;
    }

    setState(() => isParsing = true);
    try {
      final response = await http.post(
        Uri.parse('$kApiBaseUrl/parse'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': link}),
      );
      if (response.statusCode == 200) {
        _linkController.clear();
        await fetchData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ 解析成功！')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('解析失败')));
    } finally {
      setState(() => isParsing = false);
    }
  }

  Map<String, Map<String, List<dynamic>>> buildTree() {
    Map<String, Map<String, List<dynamic>>> tree = {};
    for (var item in allData) {
      var content = item['content_json'];
      String subject = content['subject'] ?? '未知学科';
      String chapter = content['chapter'] ?? '未知章节';
      tree.putIfAbsent(subject, () => {});
      tree[subject]!.putIfAbsent(chapter, () => []);
      tree[subject]![chapter]!.add(item);
    }
    return tree;
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;
    var tree = buildTree();

    Widget sidebar = Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索知识点...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
            onSubmitted: (val) {
              setState(() => _searchKeyword = val);
              fetchData();
            },
          ),
        ),
        Expanded(
          child: ListView(
            children: tree.entries.map((subjectEntry) {
              return ExpansionTile(
                title: Text('📚 ${subjectEntry.key}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                children: subjectEntry.value.entries.map((chapterEntry) {
                  return ListTile(
                    title: Text('📖 ${chapterEntry.key}'),
                    onTap: () {
                      if (!isDesktop) Navigator.pop(context);
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          insetPadding: const EdgeInsets.all(10),
                          child: SizedBox(
                            width: isDesktop ? 800 : double.maxFinite,
                            height: isDesktop ? 700 : double.maxFinite,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: chapterEntry.value.length,
                              itemBuilder: (context, index) => QuestionCard(
                                item: chapterEntry.value[index],
                                onRefresh: () {
                                  fetchData();
                                  Navigator.pop(context); // 删除后关掉弹窗
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            }).toList(),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('星知库'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchData)
        ],
      ),
      drawer: isDesktop ? null : Drawer(child: sidebar),
      body: Column(
        children: [
          // 解析输入框
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _linkController,
                    decoration: InputDecoration(
                      hintText: '粘贴 DeepSeek 链接',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: isParsing ? null : parseNewLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  child: isParsing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('解析'),
                )
              ],
            ),
          ),
          
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : isDesktop
                    ? Row(
                        children: [
                          SizedBox(width: 280, child: Material(color: Colors.grey.shade100, child: sidebar)),
                          const VerticalDivider(width: 1),
                          const Expanded(child: Center(child: Text('👈 请在左侧选择章节', style: TextStyle(fontSize: 18, color: Colors.grey)))),
                        ],
                      )
                    : const Center(child: Text('👈 点击左上角菜单选择章节', style: TextStyle(fontSize: 18, color: Colors.grey))),
          ),
        ],
      ),
    );
  }
}

// ================= 错题本页面 =================
class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});
  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  List<dynamic> favData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$kApiBaseUrl/knowledge_tree?only_favorite=true'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          favData = jsonData['data'];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⭐ 我的错题本'),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchData)
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : favData.isEmpty
              ? const Center(child: Text('还没有收藏任何题目哦~ 去知识库点个星吧！', style: TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: favData.length,
                  itemBuilder: (context, index) {
                    return QuestionCard(
                      item: favData[index],
                      onRefresh: fetchData,
                    );
                  },
                ),
    );
  }
}