import 'package:flutter/material.dart';

typedef void RadSliderDragCompleteCallback(double position);
typedef void RadSliderDragStartedCallback();

class RadSlider extends StatefulWidget {
  final double width;
  final double ballRadius;
  final Color backgroundColor;
  final Color primaryLineColor;
  final Color secondaryLineColor;
  final RadSliderDragCompleteCallback onDragComplete;
  final RadSliderDragStartedCallback onDragStart;
  final double currentPosition;

  RadSlider(this.width, this.ballRadius, {
    this.onDragComplete,
    this.onDragStart,
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
    var CONTAINER_HEIGHT = 5*widget.ballRadius;

    return new Stack(
      overflow: Overflow.visible,
      fit: StackFit.loose,
      children: <Widget>[
        new Container(
          color: widget.backgroundColor,
          width: widget.width+(5*widget.ballRadius),
          height: CONTAINER_HEIGHT,
        ),
        new Positioned(
          child: new Container(
            color: widget.secondaryLineColor,
            width: widget.width,
            height: 2.0,
          ),
          top: CONTAINER_HEIGHT/2 -1, //widget.ballRadius-1,
          left: CONTAINER_HEIGHT/2,//widget.ballRadius,
        ),
        new Positioned(
          child: new Container(
            color: widget.primaryLineColor,
            width: this.currentPosition,
            height: 2.0,
          ),
          top: CONTAINER_HEIGHT/2 -1,
          left:  CONTAINER_HEIGHT/2, //widget.ballRadius,
        ),
        new Positioned(
          child: new GestureDetector(
            child: new Stack(
              alignment: AlignmentDirectional.center,
              children: <Widget>[
                new Container(
                  width: CONTAINER_HEIGHT,
                  height: CONTAINER_HEIGHT,
                  color: Colors.grey.withAlpha(0),
                ),
                new Container(
                  decoration: new BoxDecoration(color: widget.primaryLineColor, shape: BoxShape.circle),
                  width: 2*widget.ballRadius,
                  height: 2*widget.ballRadius,
                ),
              ],
            ),
            onHorizontalDragStart: (DragStartDetails d){
              if ( widget.onDragStart != null ) {
                widget.onDragStart();
              }

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
              //print(d.globalPosition.dx.toString() + "|global|" + d.globalPosition.dx.toString());
              //print(local.dx.toString() + "|" + local.dy.toString());

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
              if ( widget.onDragComplete != null ) {
                widget.onDragComplete(this.currentPosition);
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