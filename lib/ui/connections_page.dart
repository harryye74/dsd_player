import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/smb_connection.dart';
import '../services/smb/smb_manager.dart';
import '../ui/widgets/mini_player.dart';

class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final smb = context.watch<SmbManager>();
    return Scaffold(
      appBar: AppBar(title: const Text('SMB 网盘连接')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: const Text(
              '提示：SMB 原生桥（jcifs-ng）仅在 Android / 鸿蒙(OHOS) 真机生效。'
              '桌面与 Web 仅用于演示 UI，请用"首页 → 本地演示目录"体验浏览与播放。',
              style: TextStyle(color: Colors.amber, fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          ...smb.connections.map((c) => Card(
                child: ListTile(
                  leading: const Icon(Icons.storage, color: Colors.lightBlue),
                  title: Text(c.name),
                  subtitle: Text('smb://${c.host}:${c.port}/${c.share}  用户：${c.username.isEmpty ? '匿名' : c.username}'),
                  onTap: () => _test(context, c),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.wifi_find, color: Colors.greenAccent),
                        tooltip: '测试连接',
                        onPressed: () => _test(context, c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white54),
                        onPressed: () => _showForm(context, c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => smb.remove(c.id),
                      ),
                    ],
                  ),
                ),
              )),
          if (smb.connections.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                  child: Text('还没有连接',
                      style: TextStyle(color: Colors.white38))),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('添加连接'),
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  void _showForm(BuildContext context, SmbConnection? existing) {
    showDialog(
      context: context,
      builder: (_) => _ConnectionForm(existing: existing),
    );
  }

  /// 只验证连通性，不进入浏览页；把底层错误原文弹出来便于排查
  Future<void> _test(BuildContext context, SmbConnection c) async {
    final smb = context.read<SmbManager>();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('正在测试 SMB 连接…'),
      duration: Duration(seconds: 15),
    ));
    final sw = Stopwatch()..start();
    try {
      await smb.openSmb(c);
      sw.stop();
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('连接成功（${sw.elapsedMilliseconds} ms）：${c.host}/${c.share}'),
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('连接失败：$e'),
        duration: const Duration(seconds: 15),
      ));
    }
  }
}

class _ConnectionForm extends StatefulWidget {
  final SmbConnection? existing;
  const _ConnectionForm({this.existing});

  @override
  State<_ConnectionForm> createState() => _ConnectionFormState();
}

class _ConnectionFormState extends State<_ConnectionForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _share;
  late final TextEditingController _domain;
  late final TextEditingController _user;
  late final TextEditingController _pass;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _host = TextEditingController(text: e?.host ?? '');
    _port = TextEditingController(text: '${e?.port ?? 445}');
    _share = TextEditingController(text: e?.share ?? '');
    _domain = TextEditingController(text: e?.domain ?? '');
    _user = TextEditingController(text: e?.username ?? '');
    _pass = TextEditingController(text: e?.password ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '添加 SMB 连接' : '编辑连接'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    '端口留空即用 SMB 默认 445；共享名填 NAS 上创建的共享名（如 Music），'
                    '不要填 /volume1/Music 这类路径。主机建议直接填 IP。',
                    style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                  ),
                ),
                _field(_name, '名称', '家庭 NAS'),
                _field(_host, '主机 IP（推荐）/ 域名', '192.168.1.100'),
                _field(_port, '端口（留空 = 445）', '445',
                    number: true, optional: true),
                _field(_share, '共享名', 'Music'),
                _field(_domain, '域 / 工作组（可留空）', 'WORKGROUP', optional: true),
                _field(_user, '用户名（匿名可留空）', 'guest', optional: true),
                _field(_pass, '密码', '', password: true),
              ],
            ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消')),
        ElevatedButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, String hint,
      {bool password = false, bool number = false, bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
        obscureText: password,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: (v) =>
            (v == null || v.isEmpty) && !password && !optional ? '必填' : null,
      ),
    );
  }

  void _save() async {
    if (!_form.currentState!.validate()) return;
    final conn = SmbConnection(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text,
      host: _host.text,
      port: int.tryParse(_port.text) ?? 445,
      share: _share.text,
      domain: _domain.text.isEmpty ? null : _domain.text,
      username: _user.text,
      password: _pass.text,
    );
    await context.read<SmbManager>().upsert(conn);
    if (mounted) Navigator.pop(context);
  }
}
