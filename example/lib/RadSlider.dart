import 'package:flutter/material.dart';

typedef void RadSliderCallback(double position);

class RadSlider extends StatefulWidget {
  final double width;
  final double ballRadius;
  final Color backgroundColor;
  final Color primaryLineColor;
  final Color secondaryLineColor;
  final RadSliderCallback callback;
  final double currentPosition;

  RadSlider(this.width, this.ballRadius, {
    this.callback,
    this.currentPosition = 0.0,
    this.backgroundColor = Colors.white,
    this.primaryLineColor = Colors.blue,
    this.secondaryLineColor = Colors.grey}){

      if ( this.width < this.ballRadius ){
        throw new Exception("Width is less than ballradius.");
      }
  }

  @override
  State<StatefulWidget> createState() {
    return new _RadSliderState(this.currentPosition);
  }
}

class _RadSliderState extends State<RadSlider> {
  double currentPosition;
  bool isDragging = false;

  _RadSliderState(this.currentPosition);

  @override
  void didUpdateWidget(RadSlider oldWidget){
    if ( oldWidget.currentPosition != widget.currentPosition && this.isDragging == false ){
      setState((){
        currentPosition = widget.currentPosition;
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return new Stack(
      overflow: Overflow.visible,
      children: <Widget>[
        new Container(
          color: widget.backgroundColor,
          width: widget.width+(2*widget.ballRadius),
          height: (2*widget.ballRadius),
        ),
        new Positioned(
          child: new Container(
            color: widget.secondaryLineColor,
            width: widget.width,
            height: 2.0,
          ),
          top: widget.ballRadius-1,
          left: widget.ballRadius,
        ),
        new Positioned(
          child: new Container(
            color: widget.primaryLineColor,
            width: this.currentPosition,
            height: 2.0,
          ),
          top: widget.ballRadius-1,
          left: widget.ballRadius,
        ),
        new Positioned(
          child: new GestureDetector(
            child: new Container(
              decoration: new BoxDecoration(color: widget.primaryLineColor, shape: BoxShape.circle),
              width: 2*widget.ballRadius,
              height: 2*widget.ballRadius,
            ),
            onHorizontalDragStart: (DragStartDetails d){
              this.isDragging = true;
              RenderBox box = context.findRenderObject();
              var local = box.globalToLocal(d.globalPosition);
              //print(local.dx.toString() + "|" + local.dy.toString());
              setState((){
                if ( this.currentPosition >= widget.width ){
                  this.currentPosition = widget.width;
                  return;
                }
                double newPos = local.dx-(2*widget.ballRadius);
                this.currentPosition =  newPos < 0.0 ? 0.0 : newPos;
              });
            },
            onHorizontalDragUpdate: (DragUpdateDetails d){
              RenderBox box = context.findRenderObject();
              var local = box.globalToLocal(d.globalPosition);
              print(d.globalPosition.dx.toString() + "|global|" + d.globalPosition.dx.toString());
              print(local.dx.toString() + "|" + local.dy.toString());

              setState((){
                if ( local.dx > widget.width ){
                  this.currentPosition = widget.width;
                  return;
                }
                if (local.dx <= 0.0){
                  this.currentPosition = 0.0;
                  return;
                }
                this.currentPosition = local.dx;

              });
            },
            onHorizontalDragEnd: (DragEndDetails d){
              if ( widget.callback != null ) {
                widget.callback(this.currentPosition);
              }
              this.isDragging = false;
            },
          ),
          top: 0.0,
          left: this.currentPosition,
        )
      ],
    );
  }
}