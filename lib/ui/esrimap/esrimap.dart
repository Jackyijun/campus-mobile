import 'package:flutter/material.dart';
import 'package:arcgis_maps/arcgis_maps.dart';

class EsriMaps extends StatefulWidget {
  @override
  _EsriMapsState createState() => _EsriMapsState();
}

class _EsriMapsState extends State<EsriMaps> {
  final _map = ArcGISMap.withBasemapStyle(BasemapStyle.arcGISTopographic);
  final _mapViewController = ArcGISMapView.createController();

  final _textEditingController = TextEditingController();

  final List<Map<String, String>> _layerOptions = [
    {
      'name': 'Buildings',
      'url':
      'https://services9.arcgis.com/mXNwDpiENQiMIzRv/arcgis/rest/services/aa002e/FeatureServer/0',
    },
    {
      'name': 'Resources',
      'url':
      'https://services1.arcgis.com/eGSDp8lpKe5izqVc/arcgis/rest/services/UCSD_on_campus_resources_2_WFL1/FeatureServer/0',
    },
    {
      'name': 'Regions',
      'url':
      'https://services1.arcgis.com/eGSDp8lpKe5izqVc/arcgis/rest/services/UCSD_Regions_2014/FeatureServer/0',
    },
    {
      'name':'Anna',
      'url':'https://admin-enterprise-gis.ucsd.edu/server/rest/services/AdministrationServices/Points_Of_Interest/FeatureServer/0',
    },
  ];

  late ServiceFeatureTable _featureTable;
  late FeatureLayer _featureLayer;

  String _currentLayerName = 'Buildings';
  String _message = '';
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    ArcGISEnvironment.apiKey = 'AAPTxy8BH1VEsoebNVZXo8HurEBECxvQNl6npvATkbb_hlcfhfk79rCfKobWrsCcCmQweTxAFJBE9fJ-1TkjS0p-g1FP66bFWCf4wCndJBDLUIDaQMTFwe2spC_xe_TM6D03tEp47Bj9_1kjxhWECOxgsf61xi_HdThJnG04h7tseaSMG2xVQAovU4RQwiMjCHb15BCaGW5rPqt0_VbB1ogchLzpuxHI4gLW4wzJihTee3I.AT1_jIaJXaPU';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: <Widget>[
          Column(
            children: [
              // Search Bar
              TextField(
                controller: _textEditingController,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: _dismissSearch,
                    icon: const Icon(Icons.clear),
                  ),
                ),
                onSubmitted: _onSearchSubmitted,
              ),
              // Map View
              Expanded(
                child: Stack(
                  children: [
                    ArcGISMapView(
                      controllerProvider: () => _mapViewController,
                      onMapViewReady: _onMapViewReady,
                      onTap: _onTap,
                    ),
                    if (_message.isNotEmpty)
                      Positioned(
                        top: 10,
                        left: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          color: Colors.black.withOpacity(0.7),
                          child: Text(
                            _message,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Floating Action Button for Layer Selection
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _showLayerSelection,
              child: const Icon(Icons.layers),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapViewReady() {
    _mapViewController.arcGISMap = _map;
    _loadFeatureServiceFromUri(_layerOptions[0]['url']!); // Default layer
    setState(() {
      _mapReady = true;
    });
  }

  void _loadFeatureServiceFromUri(String url) {
    final uri = Uri.parse(url);
    _featureTable = ServiceFeatureTable.withUri(uri);
    _featureLayer = FeatureLayer.withFeatureTable(_featureTable);

    _map.operationalLayers.clear();
    _map.operationalLayers.add(_featureLayer);

    _mapViewController.setViewpoint(
      Viewpoint.withLatLongScale(
        latitude: 32.8801,
        longitude: -117.2341,
        scale: 60000,
      ),
    );
  }

  void _showLayerSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: _layerOptions.length,
          itemBuilder: (context, index) {
            final layer = _layerOptions[index];
            return ListTile(
              title: Text(layer['name']!),
              onTap: () {
                Navigator.pop(context);
                _switchFeatureLayer(layer['name']!, layer['url']!);
              },
            );
          },
        );
      },
    );
  }

  void _switchFeatureLayer(String layerName, String url) {
    setState(() {
      _currentLayerName = layerName;
      _loadFeatureServiceFromUri(url);
      _message = 'Switched to $layerName Layer';
    });
  }

  void _onSearchSubmitted(String value) async {
    _featureLayer.clearSelection();

    final queryParameters = QueryParameters();
    final searchTerm = value.trim();

    // Dynamically adjust query based on the current layer
    final searchField =
    (_currentLayerName == 'Resources') ? 'Resource' : 'name';
    queryParameters.whereClause =
    "upper($searchField) LIKE '${searchTerm.toUpperCase().sqlEscape()}%'";

    final queryResult =
    await _featureTable.queryFeatures(queryParameters);

    final iterator = queryResult.features().iterator;
    if (iterator.moveNext()) {
      final feature = iterator.current;
      if (feature.geometry != null) {
        _mapViewController.setViewpointGeometry(
          feature.geometry!.extent,
          paddingInDiPs: 150.0,
        );
      }
      _featureLayer.selectFeature(feature);
    } else {
      _mapViewController.setViewpoint(Viewpoint.withLatLongScale(
        latitude: 32.8801,
        longitude: -117.2341,
        scale: 60000,
      ));
      showDialog(
        context: context,
        builder: (context) {
          return const AlertDialog(
            content: Text('No matching results found.'),
          );
        },
      );
    }
  }

  void _onTap(Offset localPosition) async {
    final identifyLayerResults = await _mapViewController.identifyLayers(
      screenPoint: localPosition,
      tolerance: 12.0,
      maximumResultsPerLayer: 10,
    );

    if (identifyLayerResults.isNotEmpty) {
      final identifiedFeatureDetails = <String>[];
      for (final result in identifyLayerResults) {
        for (final geoElement in result.geoElements) {
          if (_currentLayerName == 'Resources') {
            final location = geoElement.attributes['Location'] ?? 'N/A';
            final resource = geoElement.attributes['Resource'] ?? 'N/A';
            identifiedFeatureDetails
                .add('Location: $location\nResource: $resource');
          } else {
            final name = geoElement.attributes['name'] ?? 'N/A';
            final fid = geoElement.attributes['FID'] ?? 'N/A';
            identifiedFeatureDetails.add('Name: $name\nFID: $fid');
          }
        }
      }

      setState(() {
        _message = identifiedFeatureDetails.join('\n\n');
      });
    } else {
      setState(() {
        _message = 'No features identified.';
      });
    }
  }

  void _dismissSearch() {
    setState(() => _textEditingController.clear());
    FocusManager.instance.primaryFocus?.unfocus();
  }
}

extension on String {
  String sqlEscape() => replaceAll("'", "''");
}
