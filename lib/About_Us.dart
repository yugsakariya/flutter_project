import 'package:flutter/material.dart';

void main(){
  runApp(MaterialApp(
    home: About_Us(),
  ));
}
class About_Us extends StatefulWidget {
  const About_Us({super.key});

  @override
  State<About_Us> createState() => _About_UsState();
}

class _About_UsState extends State<About_Us> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:AppBar(
        title: Text("About Us"),
      ),
      body:SingleChildScrollView(
        child: Column(
          // crossAxisAlignment: CrossAxisAlignment.center,
          // mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: double.infinity,
                  child: Card(

                    elevation: 20,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        children: [
                          Text("Delevopers",style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
                          SizedBox(height: 10,),
                          Text("Yug Sakariya"),
                          Text("Ruchit Kadeval"),
                          Text("Darshan Lila"),
                          Text("Dev Kaneriya")
                        ]
                  ),
                )
                  )
                )
          ],
        ),
      )
    );
  }
}
