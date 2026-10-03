import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/smb/smb_manager.dart';
import '../ui/widgets/mini_player.dart';
import 'connections_page.dart';
import 'browser_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final smb = context.watch<SmbManager>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('无损 · DSD · SMB 播放器'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Hero(),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.cloud, color: Colors.lightBlue),
            title: const Text('管理 SMB 网盘连接'),
            subtitle: const Text('添加 NAS / 局域网共享（Android 真机生效）'),
            trailing: const Icon(Icons.chevron_right),
            tileColor: Colors.white.withOpacity(0.04),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConnectionsPage()),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.folder_open, color: Colors.amber),
            title: const Text('选择本地演示目录'),
            subtitle: const Text('桌面 / Web 演示：浏览并播放本地无损音乐'),
            trailing: const Icon(Icons.chevron_right),
            tileColor: Colors.white.withOpacity(0.04),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => _pickLocalDir(context),
          ),
          const SizedBox(height: 24),
          const Text('已保存的连接',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          if (smb.connections.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('还没有连接，点上方"管理 SMB 网盘连接"添加。',
                  style: TextStyle(color: Colors.white38)),
            ),
          ...smb.connections.map((c) => Card(
                color: Colors.white.withOpacity(0.04),
                child: ListTile(
                  leading: const Icon(Icons.storage, color: Colors.lightBlue),
                  title: Text(c.name),
                  subtitle: Text('${c.host}:${c.port}/${c.share}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    try {
                      await smb.openSmb(c);
                      // ignore: use_build_context_synchronously
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const BrowserPage()));
                    } catch (e) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                ),
              )),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
    );
  }

  Future<void> _pickLocalDir(BuildContext context) async {
    final smb = context.read<SmbManager>();
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return;
    await smb.openLocal(result);
    // ignore: use_build_context_synchronously
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const BrowserPage()));
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.withOpacity(0.25), Colors.deepPurple.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('高保真随身听',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('支持 FLAC / ALAC / WAV / APE 无损，'
              'DSD(.dsf/.dff) 经 USB DAC 比特完美直出，'
              '直接播放 SMB 网盘音乐。',
              style: TextStyle(color: Colors.white70, height: 1.5)),
        ],
      ),
    );
  }
}
