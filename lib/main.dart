import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(MyApp());
}

bool _isImageSelected = true; // Şəkil seçildi

bool _isSubmitted =
    false; // İstifadəçi "Elan göndər" düyməsini basıbsa, true olacaq.

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elan Yükləmə',
      theme: ThemeData.light().copyWith(
        // Açıq tema istifadə edin
        scaffoldBackgroundColor: Colors.white, // Ağ fon
        cardColor: Colors.white, // Ağ kart fonu
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.blue[50], // Açıq mavi fon
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.blue[200]!),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue,
          ), // Mavi düymələr
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue[700], // Mavi başlıq çubuğu
          foregroundColor: Colors.white, // Ağ yazılar
        ),
        iconTheme: IconThemeData(color: Colors.blue[800]), // Mavi ikonalar
        buttonTheme: ButtonThemeData(
          buttonColor: Colors.blue[600], // Mavi düymələr
          textTheme: ButtonTextTheme.primary,
        ),
      ),

      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _ads = [];
  List<Map<String, dynamic>> _filteredAds = [];
  Database? _database;
  List<File> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _initDatabase();
    _searchController.addListener(_filterAds);

    // Loading ekranı üçün 3 saniyə gecikmə
    Future.delayed(Duration(seconds: 3), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  Future<void> _initDatabase() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), 'ads_database.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE ads(id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, description TEXT, imagePaths TEXT)',
        );
      },
      version: 2,
    );
    _loadAds();
  }

  Future<void> _loadAds() async {
    if (_database == null) return;
    final List<Map<String, dynamic>> ads = await _database!.query(
      'ads',
      orderBy: 'id DESC',
    );
    setState(() {
      _ads = ads;
      _filteredAds = ads;
    });
  }

  void _filterAds() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredAds =
          _ads.where((ad) {
            return ad['title'].toString().toLowerCase().contains(query) ||
                ad['description'].toString().toLowerCase().contains(query);
          }).toList();
    });
  }

  Future<void> _submitAd() async {
    setState(() {
      _isSubmitted = true; // İstifadəçi düyməyə basıb, errorText aktiv olsun.
    });

    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(
          content: Text(
            'Zəhmət olmasa, başlıq və açıqlama sahələrini doldurun!',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedImages.isEmpty) {
      // Şəkil seçilməyibsə
      setState(() {
        _isImageSelected = false; // Şəkil seçilməyib
      });
      return;
    }

    if (_database == null) return;

    List<String> imagePaths = _selectedImages.map((img) => img.path).toList();

    await _database!.insert('ads', {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'imagePaths': imagePaths.join(','),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    _titleController.clear();
    _descriptionController.clear();

    setState(() {
      _selectedImages.clear();
      _isSubmitted = false; // Form uğurla göndərildikdə səhvlər sıfırlansın.
      _isImageSelected = false; // Göndərildikdən sonra yenidən false olsun
    });

    _loadAds();
  }

  Future<void> _deleteAd(int id) async {
    if (_database == null) return;
    await _database!.delete('ads', where: 'id = ?', whereArgs: [id]);
    _loadAds();
  }

  // Başlıq və Açıqlamanı paylaş
  Future<void> _shareTexts(int adIndex) async {
    String title = _filteredAds[adIndex]['title'];
    String description = _filteredAds[adIndex]['description'];

    String message = '$title\n\n$description';

    try {
      await Share.share(message); // Yalnız mətn paylaşılır
    } catch (e) {
      print("Xəta baş verdi: $e");
    }
  }

  // Yalnız Şəkilləri Paylaş
  Future<void> _shareImages(int adIndex) async {
    List<String> imagePaths =
        _filteredAds[adIndex]['imagePaths']?.split(',') ?? [];

    List<XFile> files = imagePaths.map((path) => XFile(path)).toList();

    try {
      if (files.isNotEmpty) {
        await Share.shareFiles(files.map((file) => file.path).toList());
      } else {
        print("Paylaşılacaq şəkil tapılmadı.");
      }
    } catch (e) {
      print("Xəta baş verdi: $e");
    }
  }

  Future<void> _pickImages() async {
    final pickedFiles = await ImagePicker().pickMultiImage();
    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        _selectedImages = pickedFiles.map((file) => File(file.path)).toList();
        _isImageSelected = true; // Şəkil seçildi
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 69, 99, 112),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Homiya',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.share),
        //     onPressed: () {
        //       // Tətbiqi paylaşma əmri
        //       Share.share('Homiya tətbiqini yükləyin: https://example.com');
        //     },
        //   ),
        // ],
      ),
      body:
          _isLoading
              ? Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SpinKitWave(color: Colors.blue, size: 50.0),
                    SizedBox(width: 10),
                    Text(
                      'HOMİYA',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => _filterAds(),
                      decoration: InputDecoration(
                        labelText: 'Elan axtar',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Başlıq',
                        border: OutlineInputBorder(),
                        errorText:
                            _isSubmitted && _titleController.text.isEmpty
                                ? 'Başlıq boş qala bilməz'
                                : null,
                      ),
                      onChanged: (text) {
                        setState(
                          () {},
                        ); // Yazı dəyişdikdə səhv mesajı yenilənsin
                      },
                    ),

                    SizedBox(height: 10),

                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Açıqlama',
                        border: OutlineInputBorder(),
                        errorText:
                            _isSubmitted && _descriptionController.text.isEmpty
                                ? 'Açıqlama boş qala bilməz'
                                : null,
                      ),
                      onChanged: (text) {
                        setState(
                          () {},
                        ); // Yazı dəyişdikdə səhv mesajı yenilənsin
                      },
                    ),

                    SizedBox(height: 10),
                    _selectedImages.isNotEmpty
                        ? SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => FullScreenImage(
                                              image: _selectedImages[index],
                                            ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      _selectedImages[index],
                                      height: 100,
                                      width: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                        : SizedBox(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImages,
                          icon: Icon(Icons.image),
                          label: Text(
                            'Şəkil Seç',
                            style:
                                _isSubmitted &&
                                        _selectedImages
                                            .isEmpty // Göndərilibsə və şəkil seçilməyibsə
                                    ? TextStyle(
                                      color: Colors.white,
                                    ) // Mətni ağ et
                                    : null, // Əks halda standart stil
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _isSubmitted && _selectedImages.isEmpty
                                    ? Colors
                                        .red // Şəkil seçilməyibsə və göndərilibsə qırmızı
                                    : null, // Əks halda standart rəng
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _submitAd,
                          child: Text('Elan Göndər'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredAds.length,
                        itemBuilder: (context, index) {
                          List<String> imagePaths =
                              _filteredAds[index]['imagePaths']?.split(',') ??
                              [];
                          return SizedBox(
                            width: double.infinity, // Genişliyi 100% etmək üçün
                            child: Card(
                              margin: EdgeInsets.all(5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                              color: const Color.fromARGB(
                                255,
                                69,
                                99,
                                112,
                              ), // Tündləşdirilmiş fon
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Align(
                                      alignment:
                                          Alignment
                                              .centerRight, // Sağ tərəfə yerləşdirir
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          _shareTexts(index);
                                        },
                                        icon: Icon(
                                          Icons.share,
                                          color:
                                              Colors
                                                  .white, // Minimalist ağ ikon
                                          size: 18, // Kiçik ikon
                                        ),
                                        label: Text(
                                          'Mətni Paylaş',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize:
                                                14, // Kiçik və minimalist mətn
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color.fromARGB(
                                            255,
                                            69,
                                            99,
                                            112,
                                          ), // Tündləşdirilmiş fon
                                          elevation: 0, // Kölgəni silir
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ), // Kiçik ölçü
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ), // Yumşaq künclər
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _filteredAds[index]['title'],
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white, // Başlıq ağ rəngdə
                                      ),
                                    ),

                                    SizedBox(height: 5),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 10,
                                      ), // Sola və sağa 10px boşluq
                                      child: Text(
                                        _filteredAds[index]['description'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              Colors
                                                  .grey[400], // Açıq boz rəngdə təsvir
                                        ),
                                      ),
                                    ),

                                    if (imagePaths.isNotEmpty)
                                      SizedBox(
                                        height: 150,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: imagePaths.length,
                                          itemBuilder: (context, imgIndex) {
                                            return GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (
                                                          context,
                                                        ) => FullScreenImageSlider(
                                                          images:
                                                              imagePaths, // Bütün şəkillər
                                                          initialIndex:
                                                              imgIndex, // Açılan şəkilin indeksi
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Image.file(
                                                  File(imagePaths[imgIndex]),
                                                  height: 150,
                                                  width: 150,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        ElevatedButton(
                                          onPressed: () {
                                            _deleteAd(
                                              _filteredAds[index]['id'],
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.white, // Ağ fon
                                            side: BorderSide(
                                              color: Colors.red,
                                            ), // Qırmızı sərhəd
                                          ),
                                          child: Text(
                                            'Sil',
                                            style: TextStyle(
                                              color: Colors.red,
                                            ), // Qırmızı rəngli düymə
                                          ),
                                        ),

                                        ElevatedButton.icon(
                                          onPressed: () {
                                            _shareImages(index);
                                          },
                                          icon: Icon(
                                            Icons.share,
                                            color:
                                                Colors.blue[800], // Mavi ikon
                                          ),
                                          label: Text(
                                            'Şəkil Paylaş',
                                            style: TextStyle(
                                              color: Colors.blue[800],
                                            ), // Mavi yazı
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors
                                                    .blue[50], // Açıq mavi fon
                                            foregroundColor:
                                                Colors
                                                    .blue[800], // Mavi yazı və ikon
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final File image;

  FullScreenImage({required this.image});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Şəkil Baxışı'),
        backgroundColor: Colors.black,
      ),
      body: Center(child: Image.file(image)),
    );
  }
}

// Tam ekran və sürüşdürülə bilən şəkil slider
class FullScreenImageSlider extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenImageSlider({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  @override
  _FullScreenImageSliderState createState() => _FullScreenImageSliderState();
}

class _FullScreenImageSliderState extends State<FullScreenImageSlider> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context), // Ekrana toxunduqda geri qayıdır
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.images.length,
          itemBuilder: (context, index) {
            return Center(
              child: Image.file(
                File(widget.images[index]),
                fit: BoxFit.contain, // Şəkil tam göstərilsin
              ),
            );
          },
        ),
      ),
    );
  }
}
