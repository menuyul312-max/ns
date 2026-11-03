"""Finite, cyclic and motion checks for CPU twin of proposed wave equations."""

from pathlib import Path
import sys
import unittest
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from surf_train_preview import wave_train, crest_distance, SURF_TRAIN_RATE


class SurfTrainCPU(unittest.TestCase):
    def test_breaker_moves_toward_shore(self):
        self.assertGreater(float(crest_distance(.25)),float(crest_distance(.75)))
        self.assertAlmostEqual(float(crest_distance(.25)-crest_distance(.75)),1.10)

    def test_finite_nonnegative_and_faded_cycle_edges(self):
        p=np.linspace(0,1,121)
        d=np.linspace(-.4,4,147)
        samples=wave_train(p[:,None],d[None,:])
        self.assertTrue(np.all(np.isfinite(samples)))
        self.assertGreaterEqual(float(samples.min()),0)
        self.assertLessEqual(float(samples.max()),1)
        self.assertTrue(np.all(samples[0]<1e-8))
        self.assertTrue(np.all(samples[-1]<1e-8))

    def test_staggered_train_wraps_without_foam_jump(self):
        d=np.linspace(0,4,201)
        for offset in (0.0,.5):
            before=wave_train((1-1e-7+offset)%1,d)
            after=wave_train((0+1e-7+offset)%1,d)
            self.assertLess(float(np.max(np.abs(before-after))),.0001)

    def test_shader_exposes_rate_and_two_fronts(self):
        source=(ROOT/'scripts/coast_builder.gd').read_text()
        self.assertIn('uniform float surf_train_rate',source)
        self.assertIn('surf_train(fract(progress + 0.5)',source)
        self.assertIn('float birth = smoothstep(0.01, 0.17, progress)',source)


if __name__=='__main__':
    unittest.main()
