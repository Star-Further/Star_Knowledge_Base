import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_math_fork/flutter_math.dart';

// 👇 这里修改为你服务器的公网 IP 和端口
const String kApiBaseUrl = 'http://121.41.198.157:8081/api';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '星知库 - AI知识库',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'HarmonyOS', // 启用鸿蒙字体
      ),
      home: const KnowledgeHomePage(),
    );
  }
}

// 混合渲染公式的组件
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
        spans.add(TextSpan(
            text: text.substring(lastMatchEnd, match.start), style: style));
      }
      String mathText = (match.group(1) ?? match.group(2) ?? '')
          .replaceAll('\\lt', '<')
          .replaceAll('\\gt', '>');
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Math.tex(
            mathText,
            textStyle: style ?? const TextStyle(fontSize: 14),
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

class KnowledgeHomePage extends StatefulWidget {
  const KnowledgeHomePage({super.key});
  @override
  State<KnowledgeHomePage> createState() => _KnowledgeHomePageState();
}

class _KnowledgeHomePageState extends State<KnowledgeHomePage> {
  List<dynamic> allData = [];
  bool isLoading = true;
  bool isParsing = false;

  final TextEditingController _linkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$kApiBaseUrl/knowledge_tree'));
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          allData = jsonData['data'];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showSnackBar('获取数据失败，请检查网络或服务器');
    }
  }

  Future<void> parseNewLink() async {
    String link = _linkController.text.trim();
    if (link.isEmpty || !link.contains('deepseek.com/share/')) {
      _showSnackBar('请输入正确的 DeepSeek 分享链接');
      return;
    }

    setState(() => isParsing = true);
    _showSnackBar('正在解析题目，请稍候（约15秒）...');

    try {
      final response = await http.post(
        Uri.parse('$kApiBaseUrl/parse'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': link}),
      );
      if (response.statusCode == 200) {
        _linkController.clear();
        _showSnackBar('✅ 解析成功！已加入知识库');
        await fetchData();
      } else {
        _showSnackBar('解析失败，请检查服务器状态');
      }
    } catch (e) {
      _showSnackBar('请求出错: $e');
    } finally {
      setState(() => isParsing = false);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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

  Widget buildDetailPage(String subject, String chapter, List<dynamic> items) {
    if (items.isEmpty) return const Center(child: Text('暂无数据'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        var content = items[index]['content_json'];
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📝 题目记录 #${items.length - index}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange)),
                const Divider(),
                const Text('💡 知识点精讲：',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ...(content['knowledge_points'] as List).map((kp) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: const Border(
                            left: BorderSide(color: Colors.orange, width: 4)),
                        borderRadius: BorderRadius.circular(4)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('📌 ${kp['title']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                                fontSize: 15)),
                        const SizedBox(height: 6),
                        RichText(
                            text: TextSpan(
                                style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                    height: 1.5),
                                children: [
                              const TextSpan(
                                  text: '概念：',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.6,
                                      child: MathText(kp['concept'] ?? '')))
                            ])),
                        const SizedBox(height: 6),
                        RichText(
                            text: TextSpan(
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 14,
                                    height: 1.5),
                                children: [
                              const TextSpan(
                                  text: '用法：',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.6,
                                      child: MathText(kp['usage'] ?? '')))
                            ])),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 12),
                const Text('📐 核心公式：',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: (content['formulas'] as List).map((f) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4)),
                      child:
                          MathText('$f', style: const TextStyle(fontSize: 15)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('🛠 解题思路与方法：',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8)),
                  child: MathText('${content['solution_method']}',
                      style: const TextStyle(height: 1.6)),
                ),
                const SizedBox(height: 16),
                const Text('🚀 举一反三：',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ...(content['similar_questions'] as List).map((sq) {
                  return Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.shade300,
                            style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MathText('变式题：${sq['question']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w500, height: 1.5)),
                        const SizedBox(height: 8),
                        MathText('解析：${sq['answer']}',
                            style: const TextStyle(
                                color: Colors.green, height: 1.5)),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;
    var tree = buildTree();

    Widget sidebar = ListView(
      children: tree.entries.map((subjectEntry) {
        return ExpansionTile(
          title: Text('📚 ${subjectEntry.key}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blue)),
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
                      child: buildDetailPage(subjectEntry.key, chapterEntry.key,
                          chapterEntry.value),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      }).toList(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('星知库 - AI知识库'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '刷新',
              onPressed: fetchData)
        ],
      ),
      drawer: isDesktop ? null : Drawer(child: sidebar),
      body: Column(
        children: [
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: isParsing ? null : parseNewLink,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                  child: isParsing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
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
                          SizedBox(
                              width: 280,
                              child: Material(
                                  color: Colors.grey.shade100, child: sidebar)),
                          const VerticalDivider(width: 1),
                          const Expanded(
                              child: Center(
                                  child: Text('👈 请在左侧选择章节',
                                      style: TextStyle(
                                          fontSize: 18, color: Colors.grey)))),
                        ],
                      )
                    : const Center(
                        child: Text('👈 点击左上角菜单选择章节',
                            style:
                                TextStyle(fontSize: 18, color: Colors.grey))),
          ),
        ],
      ),
    );
  }
}
