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
      title: 'Elan Bazası',
      theme: ThemeData.light().copyWith(
        // Açıq tema istifadə edin
        scaffoldBackgroundColor: const Color.fromRGBO(
          127,
          170,
          196,
          1,
        ), // Ağ fon
        cardColor: Colors.white, // Ağ kart fonu
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.blue[50],
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
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                    SpinKitWave(color: Colors.blue, size: 45.0),
                    SizedBox(width: 10),
                    Text(
                      'HOMİYA',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => _filterAds(),
                      decoration: InputDecoration(
                        labelText: 'Bazadan Axtarış Et',
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.indigo,
                        ), // Aksent rəngdə ikon
                        filled: true,
                        fillColor: Colors.grey.shade200, // Açıq boz dolğu
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: Colors.grey.shade300!,
                          ), // İnci boz kənar xətt
                        ),
                        focusedBorder: OutlineInputBorder(
                          // Fokuslandıqda
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(
                            color: Colors.indigoAccent,
                          ), // Aksent rəng
                        ),
                        labelStyle: TextStyle(
                          color: Colors.grey.shade600,
                        ), // İşarə mətni rəngi
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Başlıq',
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade300!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.indigoAccent),
                        ),
                        errorBorder: OutlineInputBorder(
                          // Səhv halı üçün
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.redAccent),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          // Fokusda ikən səhv halı
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.redAccent),
                        ),
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        errorText:
                            _isSubmitted && _titleController.text.isEmpty
                                ? 'Başlıq boş qala bilməz'
                                : null,
                      ),
                      onChanged: (text) {
                        setState(() {});
                      },
                    ),

                    SizedBox(height: 8),

                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Açıqlama',
                        filled: true,
                        fillColor: Colors.grey.shade200,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.grey.shade300!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.indigoAccent),
                        ),
                        errorBorder: OutlineInputBorder(
                          // Səhv halı üçün
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.redAccent),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          // Fokusda ikən səhv halı
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.redAccent),
                        ),
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        errorText:
                            _isSubmitted && _descriptionController.text.isEmpty
                                ? 'Açıqlama boş qala bilməz'
                                : null,
                      ),
                      onChanged: (text) {
                        setState(() {});
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors
                                    .green
                                    .shade400, // Və ya başqa uyğun yaşıl ton
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text('Bazaya Göndər'),
                        ),
                      ],
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredAds.length,
                        itemBuilder: (context, index) {
                          List<String> imagePaths =
                              _filteredAds
                                  .elementAt(index)['imagePaths']
                                  ?.split(',') ??
                              [];
                          return SizedBox(
                            width: double.infinity,
                            child: Card(
                              margin: EdgeInsets.only(
                                top: 10,
                                bottom: 8,
                                left: 4,
                                right: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: const Color.from(
                                    alpha: 1,
                                    red: 0.624,
                                    green: 0.659,
                                    blue: 0.855,
                                  ),
                                  width: 1.0,
                                ), // Aksent rəngində kənar xətt
                              ),
                              elevation: 2, // Daha incə kölgə
                              color: const Color.fromRGBO(
                                238,
                                238,
                                238,
                                1,
                              ), // Açıq boz fon
                              child: Padding(
                                padding: EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _shareTexts(index),
                                        icon: Icon(
                                          Icons.share,
                                          color:
                                              Colors
                                                  .indigo, // Aksent rəngdə ikon
                                          size: 16,
                                        ),
                                        label: Text(
                                          'Mətni Paylaş',
                                          style: TextStyle(
                                            color:
                                                Colors
                                                    .indigo, // Aksent rəngdə mətn
                                            fontSize: 13,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color.fromRGBO(
                                            238,
                                            238,
                                            238,
                                            1,
                                          ), // Açıq boz fon
                                          elevation: 0,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      _filteredAds.elementAt(index)['title'],
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            Colors.black87, // Tünd yazı rəngi
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      _filteredAds.elementAt(
                                        index,
                                      )['description'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            Colors
                                                .grey
                                                .shade600, // Daha açıq təsvir rəngi
                                      ),
                                    ),
                                    if (imagePaths.isNotEmpty)
                                      SizedBox(
                                        height: 80,
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
                                                        (context) =>
                                                            FullScreenImageSlider(
                                                              images:
                                                                  imagePaths,
                                                              initialIndex:
                                                                  imgIndex,
                                                            ),
                                                  ),
                                                );
                                              },
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.file(
                                                  File(
                                                    imagePaths.elementAt(
                                                      imgIndex,
                                                    ),
                                                  ),
                                                  height: 80,
                                                  width: 80,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        ElevatedButton(
                                          onPressed:
                                              () => _deleteAd(
                                                _filteredAds.elementAt(
                                                  index,
                                                )['id'],
                                              ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor:
                                                Colors
                                                    .redAccent, // Qırmızı mətn
                                            side: BorderSide(
                                              color: Colors.redAccent,
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text(
                                            'Sil',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () => _shareImages(index),
                                          icon: Icon(
                                            Icons.share,
                                            color:
                                                Colors
                                                    .indigo, // Aksent rəngdə ikon
                                            size: 16,
                                          ),
                                          label: Text(
                                            'Şəkil Paylaş',
                                            style: TextStyle(
                                              color:
                                                  Colors
                                                      .indigo, // Aksent rəngdə mətn
                                              fontSize: 13,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors
                                                    .grey
                                                    .shade200, // Açıq boz fon
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Center(child: Image.file(image, fit: BoxFit.contain)),
          Positioned(
            top: 16.0,
            right: 16.0,
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
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
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return Center(
                child: Image.file(
                  File(widget.images.elementAt(index)),
                  fit: BoxFit.contain,
                ),
              );
            },
          ),
          Positioned(
            top: 16.0,
            left: 16.0,
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            top: 16.0,
            right: 16.0,
            child: SafeArea(
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
