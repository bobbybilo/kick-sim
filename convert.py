import coremltools as ct

mlmodel = ct.convert("movenet-tensorflow2-singlepose-lightning-v4", source="tensorflow")
mlmodel.save("MoveNet.mlpackage")
